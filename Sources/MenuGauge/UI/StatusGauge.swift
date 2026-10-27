import AppKit

/// Pure mapping for the menu-bar gauge. Drawing and animation sit beside
/// these so tests can lock the two quantities the icon actually shows.
enum StatusGauge {
    static let needleSteps = 24
    /// Math degrees, 0 = east, counterclockwise. The arc is open at the bottom.
    static let arcStart = 190.0
    static let arcSweep = 200.0

    /// Both editions use `ProcessInfo.thermalState` for now. The direct
    /// download can later light segments from real temperatures; the
    /// counts stay 1...4 either way.
    static func segmentCount(for level: ThermalLevel) -> Int {
        switch level {
        case .nominal: return 1
        case .fair: return 2
        case .serious: return 3
        case .critical: return 4
        }
    }

    /// Same scale as `ThermalLevel.current`: an unknown future state is
    /// treated as serious, which lights three segments.
    static func segmentCount(for state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal: return 1
        case .fair: return 2
        case .serious: return 3
        case .critical: return 4
        @unknown default: return 3
        }
    }

    /// Quantized needle position, 0 at the left end of the arc and
    /// `needleSteps - 1` at the right end. Non-finite samples stay at 0.
    static func needleStep(cpuPercent: Double) -> Int {
        guard cpuPercent.isFinite else { return 0 }
        let clamped = min(100, max(0, cpuPercent))
        let scaled = clamped / 100 * Double(needleSteps - 1)
        return min(needleSteps - 1, max(0, Int(scaled.rounded())))
    }

    static func needleDegrees(step: Int) -> CGFloat {
        let clamped = min(needleSteps - 1, max(0, step))
        let t = Double(clamped) / Double(needleSteps - 1)
        return CGFloat(arcStart - arcSweep * t)
    }

    /// Four clockwise spans along the arc, with a gap between each.
    static func segmentSpans(gap: Double = 8) -> [(start: CGFloat, end: CGFloat)] {
        let sweep = (arcSweep - gap * 3) / 4
        var cursor = arcStart
        var spans: [(start: CGFloat, end: CGFloat)] = []
        for _ in 0..<4 {
            let end = cursor - sweep
            spans.append((CGFloat(cursor), CGFloat(end)))
            cursor = end - gap
        }
        return spans
    }
}

/// Cached template images. The menu bar tints `isTemplate` artwork, so the
/// pixels are black (or dimmed black) and never a fixed color.
enum StatusGaugeImage {
    struct Key: Hashable {
        let segments: Int
        let step: Int
        let dimmed: Bool
    }

    static let pointSize = NSSize(width: 22, height: 18)
    private static var cache: [Key: NSImage] = [:]

    static func image(for key: Key) -> NSImage {
        if let cached = cache[key] { return cached }
        let image = NSImage(size: pointSize, flipped: false) { rect in
            draw(key: key, in: rect)
            return true
        }
        image.isTemplate = true
        cache[key] = image
        return image
    }

    private static func draw(key: Key, in rect: NSRect) {
        let alpha: CGFloat = key.dimmed ? 0.28 : 1
        let color = NSColor.black.withAlphaComponent(alpha)
        color.setFill()
        color.setStroke()

        let outer: CGFloat = 8.4
        let band: CGFloat = 2.6
        let hub = CGPoint(x: rect.midX, y: rect.minY + 4.4)
        let spans = StatusGauge.segmentSpans()
        for (index, span) in spans.enumerated() {
            let path = NSBezierPath()
            path.lineCapStyle = .round
            path.lineWidth = index < key.segments ? band : 1.2
            path.appendArc(withCenter: hub, radius: outer - band / 2,
                           startAngle: span.start, endAngle: span.end, clockwise: true)
            path.stroke()
        }

        let radians = StatusGauge.needleDegrees(step: key.step) * CGFloat.pi / 180
        let direction = CGPoint(x: cos(radians), y: sin(radians))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let length = (outer - band) * 0.9
        let base: CGFloat = 1.7
        let tip = CGPoint(x: hub.x + direction.x * length, y: hub.y + direction.y * length)
        let back = CGPoint(x: hub.x - direction.x * 0.5, y: hub.y - direction.y * 0.5)
        let needle = NSBezierPath()
        needle.move(to: tip)
        needle.line(to: CGPoint(x: back.x + normal.x * base / 2, y: back.y + normal.y * base / 2))
        needle.line(to: CGPoint(x: back.x - normal.x * base / 2, y: back.y - normal.y * base / 2))
        needle.close()
        needle.fill()

        let hubRadius: CGFloat = 1.45
        NSBezierPath(ovalIn: NSRect(x: hub.x - hubRadius, y: hub.y - hubRadius,
                                    width: hubRadius * 2, height: hubRadius * 2)).fill()
    }
}

/// Samples already collected by the app become a gauge image. The needle
/// eases for a fraction of a second after each CPU sample, then the timer
/// stops. Reduce Motion jumps. A hot thermal state blinks once on entry
/// and at most every 30 seconds after that.
final class MenuBarGauge {
    var onUpdate: (() -> Void)?

    private(set) var segments = 1
    private(set) var displayedStep = 0
    private(set) var dimmed = false
    private(set) var accessibilityLabel = "MenuGauge"

    private var level: ThermalLevel?
    private var smoothed: Double?
    private var latestCPU: Double?
    private var animFrom = 0
    private var animTo = 0
    private var animStart = Date()
    private var animTimer: Timer?
    private var blinkTimer: Timer?
    private var lastBlink = Date.distantPast
    private var published = ""
    private var thermalObserver: NSObjectProtocol?
    private let animDuration = 0.36

    var imageKey: StatusGaugeImage.Key {
        StatusGaugeImage.Key(segments: segments, step: displayedStep, dimmed: dimmed)
    }

    var image: NSImage { StatusGaugeImage.image(for: imageKey) }

    func start() {
        if thermalObserver == nil {
            // The center does not keep this token alive. Dropping it would
            // stop thermal updates after start() returns.
            thermalObserver = NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil, queue: .main) { [weak self] _ in
                    self?.refreshThermal()
                }
        }
        refreshThermal()
    }

    func noteCPU(_ percent: Double?) {
        if let percent, percent.isFinite {
            latestCPU = percent
            if let previous = smoothed {
                smoothed = previous + 0.35 * (percent - previous)
            } else {
                smoothed = percent
            }
            moveNeedle(to: StatusGauge.needleStep(cpuPercent: smoothed ?? percent))
        }
        refreshLabel()
        publish()
    }

    func refreshThermal() {
        let newLevel = ThermalLevel.current
        let count = StatusGauge.segmentCount(for: newLevel)
        let hot = newLevel == .serious || newLevel == .critical
        let entered = hot && newLevel != level
        let periodic = hot && Date().timeIntervalSince(lastBlink) >= 30
        segments = count
        level = newLevel
        refreshLabel()
        publish()
        if (entered || periodic) && !reduceMotion {
            startBlink()
        }
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func moveNeedle(to target: Int) {
        if reduceMotion || target == displayedStep {
            animTimer?.invalidate()
            animTimer = nil
            displayedStep = target
            return
        }
        animFrom = displayedStep
        animTo = target
        animStart = Date()
        guard animTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            self?.tickAnimation()
        }
        RunLoop.main.add(timer, forMode: .common)
        animTimer = timer
    }

    private func tickAnimation() {
        let t = min(1, Date().timeIntervalSince(animStart) / animDuration)
        let eased = t * t * (3 - 2 * t)
        let value = Double(animFrom) + (Double(animTo) - Double(animFrom)) * eased
        displayedStep = min(StatusGauge.needleSteps - 1, max(0, Int(value.rounded())))
        if t >= 1 {
            displayedStep = animTo
            animTimer?.invalidate()
            animTimer = nil
        }
        publish()
    }

    private func startBlink() {
        blinkTimer?.invalidate()
        lastBlink = Date()
        dimmed = true
        publish()
        let timer = Timer(timeInterval: 0.14, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.dimmed = false
            self.publish()
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
    }

    private func refreshLabel() {
        let state = level.map { "\(L10n.tr(.thermalState)) \(L10n.tr($0.labelKey))" } ?? L10n.tr(.thermalState)
        if let latestCPU {
            accessibilityLabel = String(format: L10n.tr(.gaugeStatus), Int(latestCPU.rounded()), state)
        } else {
            accessibilityLabel = String(format: L10n.tr(.gaugeStatusPending), state)
        }
    }

    private func publish() {
        let token = "\(segments) \(displayedStep) \(dimmed) \(accessibilityLabel)"
        guard token != published else { return }
        published = token
        onUpdate?()
    }
}
