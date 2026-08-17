import AppKit

// Debug mode: dump raw SMC data for fan-related keys.
//   MacFan --fandump
if CommandLine.arguments.contains("--fandump") {
    guard let smc = try? SMC() else {
        print("SMC unavailable")
        exit(1)
    }
    let keys = ["FNum", "F0Ac", "F0Mn", "F0Mx", "F0Tg", "F0ID",
                "F1Ac", "F1Mn", "F1Mx", "F1Tg", "F1ID"]
    for key in keys {
        if let value = try? smc.readKey(key) {
            let hex = value.bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
            let decoded = smc.readNumber(key).map { String(format: "%.3f", $0) } ?? "?"
            print("\(key): type=\(value.type) size=\(value.size) decoded=\(decoded) raw=[\(hex)]")
        } else {
            print("\(key): <not found>")
        }
    }
    exit(0)
}

// Smoke-test mode for CLI verification of the sensor plumbing:
//   MacFan --smoke
if CommandLine.arguments.contains("--smoke") {
    let providers: [MetricProvider] = [
        CPUMonitor(), TemperatureMonitor(), FanMonitor(),
        MemoryMonitor(), DiskMonitor(), NetworkMonitor(),
    ]
    _ = providers.map { $0.sample() } // warm up (CPU/network need two samples)
    Thread.sleep(forTimeInterval: 1.0)
    for provider in providers {
        let reading = provider.sample()
        let compact = reading.compact.map { "\($0.top) / \($0.bottom)" } ?? ""
        print("\(reading.menu)   [菜单栏: \(compact)]")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
