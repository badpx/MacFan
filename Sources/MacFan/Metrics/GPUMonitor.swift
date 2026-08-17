import Foundation
import IOKit

/// GPU utilization via the IOAccelerator registry entry's
/// PerformanceStatistics dictionary — the same public IOKit source
/// powermetrics and Activity Monitor read. Apple Silicon exposes
/// "Device Utilization %"; discrete GPUs do too, and machines with no
/// such key simply report "--".
final class GPUMonitor: MetricProvider {

    let id = "gpu"

    func sample() -> MetricReading {
        guard let percent = utilization() else {
            return MetricReading(menu: "GPU: --")
        }
        return MetricReading(menu: String(format: "GPU: %.0f%%", percent),
                             compact: CompactReading(top: String(format: "%.0f%%", percent),
                                                     bottom: "GPU",
                                                     topWidthTemplate: "100%"))
    }

    private func utilization() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOAccelerator"),
                                           &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any],
                  let stats = dict["PerformanceStatistics"] as? [String: Any],
                  let value = stats["Device Utilization %"] as? NSNumber else { continue }
            return value.doubleValue
        }
        return nil
    }
}
