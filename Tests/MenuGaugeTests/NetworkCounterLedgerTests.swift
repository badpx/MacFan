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

        // A monotonic jump past the wrap cap is real traffic. Only a
        // backwards jump is limited.
        let previous: UInt32 = 10
        let current = previous + UInt32(3_500_000_000)
        XCTAssertGreaterThan(UInt64(current - previous), NetworkCounterLedger.maxPlausibleWrap)
        XCTAssertEqual(
            NetworkCounterLedger.counterDelta(current: current, previous: previous),
            UInt64(current - previous))
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

    func testThirtyTwoBitWraparoundIsCountedPerInterface() {
        let nearTop = UInt32.max - 100
        let traffic: UInt32 = 2_500_000_000
        let wrapped = nearTop &+ traffic
        XCTAssertLessThan(wrapped, nearTop)
        XCTAssertEqual(
            NetworkCounterLedger.counterDelta(current: wrapped, previous: nearTop),
            UInt64(traffic))

        var ledger = NetworkCounterLedger()
        _ = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 0xFFFF_F000, tx: 100),
            "en1": NetworkInterfaceCounters(rx: 1_000, tx: 0xFFFF_0000),
        ])
        let delta = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: 0x0000_0C00, tx: 150),
            "en1": NetworkInterfaceCounters(rx: 1_250, tx: 0x0001_0000),
        ])
        // en0 rx: 0x1000 + 0x0C00 = 7168. en1 tx: 0x10000 + 0x10000 = 131072.
        XCTAssertEqual(delta, NetworkByteDelta(rx: 7_168 + 250, tx: 50 + 131_072))

        let previous = UInt32.max
        let atLimit = previous &+ UInt32(truncatingIfNeeded: NetworkCounterLedger.maxPlausibleWrap)
        XCTAssertEqual(
            NetworkCounterLedger.counterDelta(current: atLimit, previous: previous),
            NetworkCounterLedger.maxPlausibleWrap)
    }

    func testCounterResetOrDecreaseContributesNothing() {
        let previous: UInt32 = 80_000_000
        let restarted: UInt32 = 500
        let modular = UInt64(restarted &- previous)
        XCTAssertGreaterThan(modular, NetworkCounterLedger.maxPlausibleWrap)
        XCTAssertEqual(NetworkCounterLedger.counterDelta(current: restarted, previous: previous), 0)
        XCTAssertEqual(NetworkCounterLedger.counterDelta(current: 4_000, previous: 5_000), 0)

        let past = UInt32.max &+ UInt32(truncatingIfNeeded: NetworkCounterLedger.maxPlausibleWrap + 1)
        XCTAssertEqual(NetworkCounterLedger.counterDelta(current: past, previous: .max), 0)

        var ledger = NetworkCounterLedger()
        _ = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: previous, tx: 1_000),
        ])
        let reset = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: restarted, tx: 1_100),
        ])
        XCTAssertEqual(reset, NetworkByteDelta(rx: 0, tx: 100))

        // The restarted value is the new baseline, so the next sample is real.
        let followed = ledger.advance(to: [
            "en0": NetworkInterfaceCounters(rx: restarted + 300, tx: 1_100),
        ])
        XCTAssertEqual(followed, NetworkByteDelta(rx: 300, tx: 0))
    }
}
