import AppKit
import XCTest
@testable import MenuGauge

final class NetworkCompactRateTests: XCTestCase {
    func testCompactRatesUseAtMostThreeDigits() {
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 0), "0.0K")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 40), "0.0K") // 0.04K
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 500), "0.5K")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 9_990), "10.0K") // 9.99K
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 15_800), "15.8K")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 99_940), "99.9K") // 99.94K
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 99_960), "100K") // 99.96K
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 510_000), "510K")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 999_400), "999K") // 999.4K
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 999_600), "1.0M") // 999.6K

        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 1_200_000), "1.2M")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 15_800_000), "15.8M")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 99_960_000), "100M")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 510_000_000), "510M")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 999_400_000), "999M")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 999_600_000), "1.0G")

        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 1_200_000_000), "1.2G")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 99_960_000_000), "100G")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 510_000_000_000), "510G")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 999_400_000_000), "999G")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 999_600_000_000), "999G")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: 1e15), "999G")

        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: -.nan), "0.0K")
        XCTAssertEqual(NetworkCompactRate.format(bytesPerSecond: -5), "0.0K")
    }

    func testNoCompactRateShowsFourDigits() {
        let samples = stride(from: 0, through: 2_000, by: 1).map { Double($0) * 500 }
            + [99_940, 99_950, 99_960, 999_400, 999_500, 999_600]
            + [99_960_000, 999_600_000, 99_960_000_000, 999_600_000_000, 1e15]
        for rate in samples {
            let text = NetworkCompactRate.format(bytesPerSecond: rate)
            let digits = text.filter(\.isNumber).count
            XCTAssertLessThanOrEqual(digits, 3, text)
            XCTAssertFalse(text.contains("100.0"), text)
            XCTAssertFalse(text.contains("1000"), text)
            XCTAssertTrue(text.hasSuffix("K") || text.hasSuffix("M") || text.hasSuffix("G"), text)
        }
    }

    func testColumnWidthIsTheWidestShapeWithNoSlack() {
        let font = NetworkCompactRate.menuFont
        func width(_ text: String) -> CGFloat {
            NetworkCompactRate.measure(text, font: font)
        }
        let digit = NetworkCompactRate.widestDigit(measuring: width)
        let candidates = NetworkCompactRate.widthCandidates(widestDigit: digit)
        let widest = candidates.map(width).max() ?? 0
        XCTAssertEqual(width(NetworkCompactRate.widthTemplate), widest, accuracy: 0.001)
        XCTAssertEqual(NetworkCompactRate.columnWidth, widest, accuracy: 0.001)
        XCTAssertEqual(NetworkCompactRate.widthTemplate, candidates.max { width($0) < width($1) })

        var seen = Set<String>()
        let probes: [Double] = [0, 40, 50, 500, 9_990, 15_800, 99_940, 99_960,
                                100_000, 510_000, 999_400, 999_600,
                                1_200_000, 99_960_000, 510_000_000, 999_600_000,
                                1_200_000_000, 510_000_000_000, 999_600_000_000]
        for rate in probes {
            seen.insert(NetworkCompactRate.format(bytesPerSecond: rate))
        }
        for body in seen {
            for arrow in ["↑", "↓"] {
                let row = arrow + body
                XCTAssertLessThanOrEqual(width(row), NetworkCompactRate.columnWidth, row)
            }
        }
        XCTAssertLessThanOrEqual(width("↓--"), NetworkCompactRate.columnWidth + 0.001)
    }
}
