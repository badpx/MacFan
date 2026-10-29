import XCTest
@testable import MenuGauge

final class NetworkCounterLedgerTests: XCTestCase {
    func testSteadyTrafficSumsPerInterfaceDeltas() {
        var ledger = NetworkCounterLedger()
        let seeded = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 1_000, tx: 200),
            "en1": NetworkInterfaceCounters(rx: 50, tx: 10),
        ])
        XCTAssertEqual(seeded, .zero)

        let steady = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 1_500, tx: 200),
            "en1": NetworkInterfaceCounters(rx: 80, tx: 40),
        ])
        XCTAssertEqual(steady, NetworkByteDelta(rx: 530, tx: 30))

        // 64-bit counters keep counting past 4 GiB. The increase is real.
        let previous: UInt64 = 5_000_000_000
        let current = previous + 1_500
        XCTAssertEqual(
            NetworkCounterLedger.counterDelta(current: current, previous: previous),
            1_500)
    }

    func testInterfaceAddedContributesNothingOnFirstSight() {
        var ledger = NetworkCounterLedger()
        _ = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 4_000, tx: 8_000),
        ])

        let added = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 4_010, tx: 8_040),
            "en2": NetworkInterfaceCounters(rx: 9_000_000, tx: 1_000_000),
        ])
        XCTAssertEqual(added, NetworkByteDelta(rx: 10, tx: 40))
        XCTAssertEqual(ledger.baseline["en2"], NetworkInterfaceCounters(rx: 9_000_000, tx: 1_000_000))

        let followed = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 4_010, tx: 8_040),
            "en2": NetworkInterfaceCounters(rx: 9_000_100, tx: 1_000_025),
        ])
        XCTAssertEqual(followed, NetworkByteDelta(rx: 100, tx: 25))
    }

    func testInterfaceRemovedDropsItsBaseline() {
        var ledger = NetworkCounterLedger()
        _ = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 1_000, tx: 2_000),
            "en5": NetworkInterfaceCounters(rx: 3_000_000_000, tx: 2_500_000_000),
        ])

        // Dropping en5 removes billions of bytes from the summed total.
        // The diff must be en0's own increase, not a wrapped ~2^64 gap.
        let removed = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 1_025, tx: 2_010),
        ])
        XCTAssertEqual(removed, NetworkByteDelta(rx: 25, tx: 10))
        XCTAssertEqual(ledger.baseline.keys.sorted(), ["en0"])

        // The same name coming back is a new interface: its history,
        // including the 100 bytes since we last saw it, is not traffic.
        let returned = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 1_030, tx: 2_010),
            "en5": NetworkInterfaceCounters(rx: 3_000_000_100, tx: 2_500_000_000),
        ])
        XCTAssertEqual(returned, NetworkByteDelta(rx: 5, tx: 0))
    }

    func testLargeCounterResetContributesNothing() {
        // A 32-bit reading of this drop used to look like a wrap of
        // 2_294_967_796 bytes. With 64-bit counters it is a reset.
        XCTAssertEqual(
            NetworkCounterLedger.counterDelta(current: 500, previous: 2_000_000_000),
            0)
        XCTAssertEqual(
            NetworkCounterLedger.counterDelta(current: 4_000, previous: 5_000),
            0)

        var ledger = NetworkCounterLedger()
        _ = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 2_000_000_000, tx: 1_000),
        ])
        let reset = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 500, tx: 1_100),
        ], elapsed: 2)
        XCTAssertEqual(reset, NetworkByteDelta(rx: 0, tx: 100))
        XCTAssertEqual(ledger.baseline["en0"]?.rx, 500)

        let followed = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 800, tx: 1_100),
        ], elapsed: 2)
        XCTAssertEqual(followed, NetworkByteDelta(rx: 300, tx: 0))
    }

    func testBaudrateCapTreatsAnImpossibleJumpAsAReset() {
        // 1 Gbit/s over 2s, times the margin, is 500_000_000 bytes.
        let gigabit: UInt64 = 1_000_000_000
        let elapsed: TimeInterval = 2
        let within = NetworkCounterLedger.counterDelta(
            current: 100_000_000, previous: 0, baudrate: gigabit, elapsed: elapsed)
        XCTAssertEqual(within, 100_000_000)
        let over = NetworkCounterLedger.counterDelta(
            current: 600_000_000, previous: 0, baudrate: gigabit, elapsed: elapsed)
        XCTAssertEqual(over, 0)
        // Unknown link speed does not cap a large forward jump.
        XCTAssertEqual(
            NetworkCounterLedger.counterDelta(current: 600_000_000, previous: 0, baudrate: 0, elapsed: elapsed),
            600_000_000)

        var ledger = NetworkCounterLedger()
        _ = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 1_000, tx: 1_000, baudrate: gigabit),
        ])
        let capped = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 1_000 + 600_000_000, tx: 1_050, baudrate: gigabit),
        ], elapsed: elapsed)
        XCTAssertEqual(capped, NetworkByteDelta(rx: 0, tx: 50))
    }
}
