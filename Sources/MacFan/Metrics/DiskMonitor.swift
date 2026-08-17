import Foundation

/// System volume usage via file system attributes.
final class DiskMonitor: MetricProvider {

    func sample() -> String {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64,
              let free = attrs[.systemFreeSize] as? Int64,
              total > 0 else {
            return "磁盘: --"
        }

        let used = total - free
        let percent = Double(used) / Double(total) * 100.0
        return String(format: "磁盘: 已用 %@ / %@ (%.0f%%)",
                      Self.format(bytes: used),
                      Self.format(bytes: total),
                      percent)
    }

    private static func format(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
