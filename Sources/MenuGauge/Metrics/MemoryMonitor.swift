import Foundation
import Darwin.Mach

/// Physical memory usage via host_statistics64. "Used" follows the
/// Activity Monitor convention: app memory + wired + compressed.
/// The text color follows system memory pressure, not the usage
/// percentage; a 90 %-full Mac is not necessarily under pressure.
final class MemoryMonitor: MetricProvider {

    let id = "memory"

    private let totalBytes = ProcessInfo.processInfo.physicalMemory
    private let pressure: () -> MemoryPressure

    init(pressure: @escaping () -> MemoryPressure = { MemoryPressure.current }) {
        self.pressure = pressure
    }

    func sample() -> MetricReading {
        guard let used = usedBytes() else { return MetricReading(menu: "\(L10n.tr(.memory)): --") }

        let percent = Double(used) / Double(totalBytes) * 100.0
        let heat = pressure().heat
        let menu = String(format: "%@: %.1f / %.0f GB (%@ %.0f%%)",
                          L10n.tr(.memory),
                          Double(used) / 1_073_741_824.0,
                          Double(totalBytes) / 1_073_741_824.0,
                          L10n.tr(.used),
                          percent)
        return MetricReading(menu: menu,
                             compact: CompactReading(top: String(format: "%.0f%%", percent),
                                                     bottom: "RAM",
                                                     topWidthTemplate: "100%"),
                             heat: heat,
                             value: .capacity(used: Double(used) / 1_073_741_824,
                                              total: Double(totalBytes) / 1_073_741_824))
    }

    private func usedBytes() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride
                                           / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        // Activity Monitor: Memory Used = App Memory + Wired + Compressed,
        // where App Memory = internal (anonymous) pages minus purgeable pages.
        // File-backed pages (external_page_count) are cache and must not count.
        let pageSize = UInt64(vm_kernel_page_size)
        return (UInt64(stats.internal_page_count)
                - UInt64(stats.purgeable_count)
                + UInt64(stats.wire_count)
                + UInt64(stats.compressor_page_count)) * pageSize
    }
}
