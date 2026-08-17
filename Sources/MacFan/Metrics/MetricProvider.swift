import Foundation

/// A single system metric shown as one line in the menu.
/// Conform for future metrics (disk, memory, network...) — the menu
/// controller renders whatever the providers return.
protocol MetricProvider {
    /// One formatted line for the menu, e.g. "CPU: 12.3 %".
    func sample() -> String
}
