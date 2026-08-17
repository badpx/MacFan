import Foundation

/// System volume usage via file system attributes.
final class DiskMonitor: MetricProvider {

    let id = "disk"

    func sample() -> MetricReading {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64,
              let free = attrs[.systemFreeSize] as? Int64,
              total > 0 else {
            return MetricReading(menu: "\(L10n.tr(.disk)): --")
        }

        let used = total - free
        let percent = Double(used) / Double(total) * 100.0
        let gb = 1_073_741_824.0
        let menu = String(format: "%@: %@ %.0f / %.0f GB (%.0f%%)",
                          L10n.tr(.disk), L10n.tr(.used),
                          Double(used) / gb,
                          Double(total) / gb,
                          percent)
        return MetricReading(menu: menu,
                             compact: CompactReading(top: String(format: "%.0f%%", percent),
                                                     bottom: "SSD"))
    }
}
