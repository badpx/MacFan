import AppKit

/// Menu bar controller: one status item, one 2s timer, nothing else.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?

    /// Ordered metrics; add new providers here (disk, memory, network...).
    private let providers: [MetricProvider] = [
        CPUMonitor(),
        TemperatureMonitor(),
        FanMonitor(),
        MemoryMonitor(),
        DiskMonitor(),
        NetworkMonitor(),
    ]
    private var metricItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let symbolName = NSImage(systemSymbolName: "fan", accessibilityDescription: nil) != nil
                ? "fan" : "gauge.medium"
            button.image = NSImage(systemSymbolName: symbolName,
                                   accessibilityDescription: "MacFan")
            button.image?.isTemplate = true
        }

        menu = NSMenu()
        menu.delegate = self

        for _ in providers {
            let item = NSMenuItem(title: "--", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            metricItems.append(item)
        }

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "开机自启动",
                                   action: #selector(toggleLaunchAtLogin),
                                   keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 MacFan",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        refresh()
        // .common modes: keeps ticking while the menu is open
        // (an open menu puts the run loop into event tracking mode).
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Refresh right before the menu opens so values are never stale.
    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        menu.item(withTitle: "开机自启动")?.state = LoginItem.isEnabled ? .on : .off
    }

    private func refresh() {
        for (item, provider) in zip(metricItems, providers) {
            item.title = provider.sample()
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LoginItem.setEnabled(sender.state != .on)
        sender.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
