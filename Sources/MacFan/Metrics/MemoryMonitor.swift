import Foundation
import Darwin.Mach

/// Physical memory usage via host_statistics64. "Used" follows the
/// Activity Monitor convention: app memory + wired + compressed.
final class MemoryMonitor: MetricProvider {

    private let totalBytes = ProcessInfo.processInfo.physicalMemory

    func sample() -> String {
        guard let used = usedBytes() else { return "内存: --" }

        let totalGB = Double(totalBytes) / 1_073_741_824.0
        let usedGB = Double(used) / 1_073_741_824.0
        let percent = Double(used) / Double(totalBytes) * 100.0
        return String(format: "内存: %.1f / %.0f GB (%.0f%%)", usedGB, totalGB, percent)
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

        let pageSize = UInt64(vm_kernel_page_size)
        return (UInt64(stats.active_count)
                + UInt64(stats.wire_count)
                + UInt64(stats.compressor_page_count)
                - UInt64(stats.purgeable_count)
                + UInt64(stats.external_page_count)) * pageSize
    }
}
