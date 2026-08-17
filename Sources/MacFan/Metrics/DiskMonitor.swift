import Foundation

/// System volume usage via URL resource values.
/// Uses `volumeAvailableCapacityForImportantUsage`, which counts purgeable
/// space (local snapshots, caches) as available — matching the usage shown
/// in Finder and System Settings. `statfs`/`systemFreeSize` would report
/// purgeable space as used and overstate usage.
final class DiskMonitor: MetricProvider {

    let id = "disk"

    func sample() -> MetricReading {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage,
              total > 0 else {
            return MetricReading(menu: "\(L10n.tr(.disk)): --")
        }

        let used = Int64(total) - available
        let percent = Double(used) / Double(total) * 100.0
        let gb = 1_073_741_824.0
        let menu = String(format: "%@: %@ %.0f / %.0f GB (%.0f%%)",
                          L10n.tr(.disk), L10n.tr(.used),
                          Double(used) / gb,
                          Double(total) / gb,
                          percent)
        return MetricReading(menu: menu,
                             compact: CompactReading(top: String(format: "%.0f%%", percent),
                                                     bottom: "SSD",
                                                     topWidthTemplate: "100%"))
    }
}
