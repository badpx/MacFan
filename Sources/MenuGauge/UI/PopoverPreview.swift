#if DEBUG
import AppKit
import SwiftUI

/// Deterministic native rendering for design QA; never touches preferences,
/// sensors or login registration. Only included in debug builds.
enum PopoverPreview {
    private final class PreviewWindow: NSWindow {
        override var canBecomeKey: Bool { true }
    }

    private struct Scenario {
        var name: String
        var appearance: NSAppearance.Name
        var width: CGFloat
        var height: CGFloat
        var settings: Bool
        var heat = false
        var unavailable = false
        var login: LoginItem.State = .enabled
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
        let panel = NSHostingController(rootView: PopoverView(model: model))
        let settings = NSHostingController(rootView: SettingsView(model: model, onQuit: {}))
        let window = PreviewWindow(contentRect: NSRect(x: 100, y: 100, width: 384, height: 330),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = panel
        window.isReleasedWhenClosed = false
        app.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        let directory = URL(fileURLWithPath: output, isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { fputs("\(error)\n", stderr); exit(1) }

        let scenarios: [Scenario] = [
            .init(name: "native-light", appearance: .aqua, width: 384, height: 330, settings: false),
            .init(name: "native-dark", appearance: .darkAqua, width: 384, height: 330, settings: false),
            .init(name: "native-heat", appearance: .darkAqua, width: 384, height: 330, settings: false, heat: true),
            .init(name: "native-unavailable", appearance: .aqua, width: 384, height: 330, settings: false, unavailable: true),
            .init(name: "native-short-screen", appearance: .aqua, width: 384, height: 240, settings: false),
            .init(name: "native-settings", appearance: .aqua, width: 520, height: 760, settings: true),
            .init(name: "native-settings-dark", appearance: .darkAqua, width: 520, height: 760, settings: true),
            .init(name: "native-settings-pending", appearance: .aqua, width: 520, height: 760, settings: true,
                  login: .requiresApproval),
        ]
        var index = 0
        func next() {
            guard index < scenarios.count else { window.close(); exit(0) }
            let scenario = scenarios[index]
            window.appearance = NSAppearance(named: scenario.appearance)
            model.loginState = scenario.login
            model.loginError = nil
            model.height = scenario.height
            model.readings["temperature"] = .init(menu: "", value: .temperature(51.9))
            model.readings["memory"] = .init(menu: "", value: .capacity(used: 24.2, total: 32))
            model.readings["fan"] = .init(menu: "", value: .fan(0))
            model.readings["network"] = .init(menu: "", value: .network(download: 32_100, upload: 10_200))
            if scenario.heat {
                model.readings["temperature"] = .init(menu: "", heat: ThermalPressure.trapping.heat, value: .temperature(82.4))
                model.readings["memory"] = .init(menu: "", heat: 0, value: .capacity(used: 27.2, total: 32))
                model.readings["fan"] = .init(menu: "", value: .fan(2000))
            }
            if scenario.unavailable {
                model.readings["fan"] = .init(menu: "")
                model.readings["network"] = .init(menu: "", value: .network(download: nil, upload: 10_200))
            }
            window.contentViewController = scenario.settings ? settings : panel
            window.setContentSize(NSSize(width: scenario.width, height: scenario.height))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                let view = window.contentViewController?.view ?? panel.view
                view.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
                do { try png.write(to: directory.appendingPathComponent(scenario.name + ".png")) }
                catch { fputs("\(error)\n", stderr); exit(1) }
                let chrome = PopoverView.chromeHeight
                print("Rendered \(scenario.name) (content \(model.contentHeight)pt -> popover \(ceil(model.contentHeight + chrome))pt)")
                index += 1
                next()
            }
        }
        DispatchQueue.main.async { next() }
        app.run()
    }
}
#endif
