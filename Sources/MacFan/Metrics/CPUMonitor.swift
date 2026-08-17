import Foundation
import Darwin.Mach

/// Overall CPU usage computed from the delta between two
/// host_processor_info samples.
final class CPUMonitor: MetricProvider {

    let id = "cpu"

    private var previous: [UInt32]?

    func sample() -> MetricReading {
        guard let usage = measureUsage() else {
            return MetricReading(menu: "CPU: --")
        }
        return MetricReading(menu: String(format: "CPU: %.1f %%", usage),
                             compact: CompactReading(top: String(format: "%.0f%%", usage),
                                                     bottom: "CPU",
                                                     topWidthTemplate: "100%"))
    }

    private func measureUsage() -> Double? {
        guard let ticks = readTicks() else { return nil }
        defer { previous = ticks }

        guard let previous, previous.count == ticks.count else { return nil }

        var totalDelta: UInt32 = 0
        var idleDelta: UInt32 = 0
        for index in 0..<ticks.count {
            totalDelta &+= ticks[index] &- previous[index]
        }
        // Ticks are laid out per-CPU as [user, system, idle, nice] x cpuCount.
        for index in stride(from: Int(CPU_STATE_IDLE), to: ticks.count, by: Int(CPU_STATE_MAX)) {
            idleDelta &+= ticks[index] &- previous[index]
        }

        guard totalDelta > 0 else { return nil }
        return (1.0 - Double(idleDelta) / Double(totalDelta)) * 100.0
    }

    private func readTicks() -> [UInt32]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(),
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &cpuCount,
                                         &info,
                                         &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let count = Int(cpuCount) * Int(CPU_STATE_MAX)
        return Array(UnsafeBufferPointer(start: info, count: count)).map(UInt32.init(bitPattern:))
    }
}
