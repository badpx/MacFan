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

    /// Outer radius, band width, and clear gap used by the menu-bar image.
    /// The arc passes through due east and due west, so its ink is
    /// `2 * menuOuterRadius` wide. The angular gap is wide enough that
    /// round caps still leave `menuClearGap` of the background between
    /// neighboring segments.
    static let menuOuterRadius: Double = 9.6
    static let menuBand: Double = 2.4
    static let menuClearGap: Double = 1.2
    static let menuCenterlineRadius: Double = menuOuterRadius - menuBand / 2
    static let menuSegmentGap: Double = (menuClearGap + menuBand) / menuCenterlineRadius * 180 / .pi

    /// The gauge replaces the metrics, the way the old fan symbol did.
    /// It is shown only when the bar is not drawing any metric.
    static func showsGauge(renderedMetricCount: Int) -> Bool {
        renderedMetricCount <= 0
    }

    /// Four clockwise spans along the arc, with a gap between each.
    static func segmentSpans(gap: Double = menuSegmentGap) -> [(start: CGFloat, end: CGFloat)] {
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

    /// 20×16pt is the status-bar slot: a ~22pt bar minus about 3pt of padding
    /// on the short side. The 200° arc is ~19pt wide, so it cannot also be
    /// 16pt tall; the ink is centered in this slot instead of letterboxed
    /// against the top.
    static let pointSize = NSSize(width: 20, height: 16)
    static var bandStroke: CGFloat { CGFloat(StatusGauge.menuBand) }
    static var outerRadius: CGFloat { CGFloat(StatusGauge.menuOuterRadius) }
    static let hubRadius: CGFloat = 1.25
    static let needleWidth: CGFloat = 1.8
    /// Empty segments stay the same stroke and use alpha so a template image dims them.
    static let emptyAlpha: CGFloat = 0.37

    /// Hub of the arc in a canvas of `size`, y-up. Includes the round caps
    /// hanging past the open ends so the ink stays inside the image.
    static func hubOrigin(in size: NSSize) -> CGPoint {
        let dip = (outerRadius - bandStroke / 2) * sin(10 * .pi / 180) + bandStroke / 2
        let glyphHeight = outerRadius + dip
        let bottom = (size.height - glyphHeight) / 2
        return CGPoint(x: size.width / 2, y: bottom + dip)
    }

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
        // Black pixels only. `isTemplate` turns alpha into the menu-bar tint,
        // including the highlighted state, once the image is the button image.
        let dim: CGFloat = key.dimmed ? 0.28 : 1
        let centerline = outerRadius - bandStroke / 2
        let hub = hubOrigin(in: rect.size)
        let spans = StatusGauge.segmentSpans(gap: StatusGauge.menuSegmentGap)
        for (index, span) in spans.enumerated() {
            let filled = index < key.segments
            NSColor.black.withAlphaComponent(dim * (filled ? 1 : emptyAlpha)).setStroke()
            let path = NSBezierPath()
            path.lineCapStyle = .round
            path.lineWidth = bandStroke
            path.appendArc(withCenter: hub, radius: centerline,
                           startAngle: span.start, endAngle: span.end, clockwise: true)
            path.stroke()
        }

        NSColor.black.withAlphaComponent(dim).setFill()
        let radians = StatusGauge.needleDegrees(step: key.step) * CGFloat.pi / 180
        let direction = CGPoint(x: cos(radians), y: sin(radians))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let inner = centerline - bandStroke / 2
        let length = max(hubRadius + 1.5, inner - 0.6)
        let tipReach = length - 0.45
        let base = needleWidth
        let tipWidth: CGFloat = 0.7
        let tip = CGPoint(x: hub.x + direction.x * tipReach, y: hub.y + direction.y * tipReach)
        let back = CGPoint(x: hub.x - direction.x * 0.2, y: hub.y - direction.y * 0.2)
        let needle = NSBezierPath()
        needle.move(to: CGPoint(x: tip.x + normal.x * tipWidth / 2, y: tip.y + normal.y * tipWidth / 2))
        needle.line(to: CGPoint(x: back.x + normal.x * base / 2, y: back.y + normal.y * base / 2))
        needle.line(to: CGPoint(x: back.x - normal.x * base / 2, y: back.y - normal.y * base / 2))
        needle.line(to: CGPoint(x: tip.x - normal.x * tipWidth / 2, y: tip.y - normal.y * tipWidth / 2))
        needle.close()
        needle.fill()
        let tipRadius = tipWidth / 2
        NSBezierPath(ovalIn: NSRect(x: tip.x - tipRadius, y: tip.y - tipRadius,
                                    width: tipWidth, height: tipWidth)).fill()

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
