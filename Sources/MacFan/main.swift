import AppKit

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
        print(provider.sample())
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
