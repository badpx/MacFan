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
        // Decimal GB (10^9), matching Finder/System Settings; binary GiB (2^30)
        // would understate both used and total by ~7% under a "GB" label.
        let gb = 1_000_000_000.0
        // Warn from 80 % full (light orange) ramping to red at 90 %.
        let heat: Double? = percent >= 80
            ? min((percent - 80) / 10, 1) : nil
        let menu = String(format: "%@: %.0f / %.0f GB (%@ %.0f%%)",
                          L10n.tr(.disk),
                          Double(used) / gb,
                          Double(total) / gb,
                          L10n.tr(.used),
                          percent)
        return MetricReading(menu: menu,
                             compact: CompactReading(top: String(format: "%.0f%%", percent),
                                                     bottom: "SSD",
                                                     topWidthTemplate: "100%"),
                             heat: heat,
                             value: .capacity(used: Double(used) / gb, total: Double(total) / gb))
    }
}
