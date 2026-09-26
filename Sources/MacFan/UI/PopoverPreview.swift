#if DEBUG
import AppKit
import SwiftUI

/// Deterministic native rendering for design QA; never touches preferences,
/// sensors or login registration. Only included in debug builds.
enum PopoverPreview {
    private final class PreviewWindow: NSWindow {
        override var canBecomeKey: Bool { true }
    }
    static func run(output: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let model = PopoverModel()
        model.selectedIDs = ["cpu", "memory", "temperature", "network"]
        model.loginState = .enabled
        model.readings = [
            "cpu": .init(menu: "", value: .percent(20.1)),
            "gpu": .init(menu: "", value: .percent(4)),
            "memory": .init(menu: "", value: .capacity(used: 24.2, total: 32)),
            "disk": .init(menu: "", value: .capacity(used: 326, total: 995)),
            "temperature": .init(menu: "", value: .temperature(51.9)),
            "fan": .init(menu: "", value: .fan(0)),
            "network": .init(menu: "", value: .network(download: 32_100, upload: 10_200)),
        ]
        let controller = NSHostingController(rootView: PopoverView(model: model))
        let window = PreviewWindow(contentRect: NSRect(x: 100, y: 100, width: 384, height: 724),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        app.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        let directory = URL(fileURLWithPath: output, isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { fputs("\(error)\n", stderr); exit(1) }

        let scenarios: [(String, NSAppearance.Name, PopoverPage, CGFloat)] = [
            ("native-light", .aqua, .overview, 724),
            ("native-dark", .darkAqua, .overview, 724),
            ("native-settings", .aqua, .configuration, 672),
            ("native-heat", .darkAqua, .overview, 724),
            ("native-unavailable", .aqua, .overview, 724),
            ("native-short-screen", .aqua, .overview, 520),
        ]
        var index = 0
        func next() {
            guard index < scenarios.count else { window.close(); exit(0) }
            let (name, appearance, page, height) = scenarios[index]
            window.appearance = NSAppearance(named: appearance)
            model.page = page
            model.height = height
            if name == "native-heat" {
                model.readings["temperature"] = .init(menu: "", heat: 0.74, value: .temperature(82.4))
                model.readings["memory"] = .init(menu: "", heat: 0.5, value: .capacity(used: 27.2, total: 32))
                model.readings["fan"] = .init(menu: "", value: .fan(2000))
            }
            if name == "native-unavailable" {
                model.readings["fan"] = .init(menu: "")
                model.readings["network"] = .init(menu: "", value: .network(download: nil, upload: 10_200))
            }
            window.setContentSize(NSSize(width: 384, height: height))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let view = controller.view
                view.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
                do { try png.write(to: directory.appendingPathComponent(name + ".png")) }
                catch { fputs("\(error)\n", stderr); exit(1) }
                print("Rendered \(name)")
                index += 1
                next()
            }
        }
        DispatchQueue.main.async { next() }
        app.run()
    }
}
#endif
