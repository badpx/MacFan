import Foundation
import XCTest
@testable import MenuGauge

final class MetricAccentTests: XCTestCase {
    func testEveryMetricHasAUniqueAccentInBothAppearances() {
        let ids = MetricCatalog.offeredDescriptors(appStore: false)
            .map(\.id)
            .filter { $0 != MetricCatalog.logoID }
        XCTAssertEqual(Set(ids), Set(MetricAccent.ids))
        XCTAssertEqual(Set(ids.map(MetricAccent.lightHex(for:))).count, ids.count)
        XCTAssertEqual(Set(ids.map(MetricAccent.darkHex(for:))).count, ids.count)
    }

    func testMetricAccentsAreFarEnoughApartToTellApart() {
        let appearances: [(String, [UInt32])] = [
            ("light", MetricAccent.ids.map(MetricAccent.lightHex(for:))),
            ("dark", MetricAccent.ids.map(MetricAccent.darkHex(for:))),
        ]
        // A coarse RGB guard, not a full ΔE measurement: it catches pairs
        // that are so close that the dot/icon identity becomes ambiguous.
        let minimumDistance = 50.0
        for (appearance, hexes) in appearances {
            for first in 0..<hexes.count {
                for second in (first + 1)..<hexes.count {
                    let distance = rgbDistance(hexes[first], hexes[second])
                    XCTAssertGreaterThanOrEqual(
                        distance, minimumDistance,
                        "\(appearance): \(MetricAccent.ids[first]) and " +
                        "\(MetricAccent.ids[second]) are too close (\(distance))")
                }
            }
        }
    }

    func testLogoIsNotAMetricAccent() {
        XCTAssertFalse(MetricAccent.ids.contains(MetricCatalog.logoID))
    }

    private func rgbDistance(_ lhs: UInt32, _ rhs: UInt32) -> Double {
        let lr = Double((lhs >> 16) & 255), lg = Double((lhs >> 8) & 255), lb = Double(lhs & 255)
        let rr = Double((rhs >> 16) & 255), rg = Double((rhs >> 8) & 255), rb = Double(rhs & 255)
        return sqrt((lr - rr) * (lr - rr) + (lg - rg) * (lg - rg) + (lb - rb) * (lb - rb))
    }
}
