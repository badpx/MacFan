import XCTest
@testable import MenuGauge

final class SingleInstanceTests: XCTestCase {
    private let bundle = "com.badpx.macfan"

    func testSecondCopyYieldsToTheRunningInstance() {
        let peers = [
            SingleInstancePeer(bundleIdentifier: bundle, processIdentifier: 10),
            SingleInstancePeer(bundleIdentifier: bundle, processIdentifier: 42),
        ]
        XCTAssertTrue(SingleInstance.shouldYield(
            bundleIdentifier: bundle, currentPID: 42, peers: peers, arguments: []))
        XCTAssertTrue(SingleInstance.shouldYield(
            bundleIdentifier: bundle, currentPID: 10, peers: peers, arguments: []))
    }

    func testFirstCopyDoesNotYield() {
        let peers = [
            SingleInstancePeer(bundleIdentifier: bundle, processIdentifier: 42),
            SingleInstancePeer(bundleIdentifier: "com.apple.finder", processIdentifier: 1),
            SingleInstancePeer(bundleIdentifier: nil, processIdentifier: 7),
        ]
        XCTAssertFalse(SingleInstance.shouldYield(
            bundleIdentifier: bundle, currentPID: 42, peers: peers, arguments: []))
    }

    func testSnapshotKeepsRunningBesideTheRealApp() {
        let peers = [
            SingleInstancePeer(bundleIdentifier: bundle, processIdentifier: 10),
            SingleInstancePeer(bundleIdentifier: bundle, processIdentifier: 99),
        ]
        XCTAssertFalse(SingleInstance.shouldYield(
            bundleIdentifier: bundle, currentPID: 99, peers: peers,
            arguments: ["MenuGauge", "--ui-snapshot", "/tmp/out"]))
    }

    func testHandoffPostHasNoUserInfo() {
        XCTAssertNil(SingleInstance.handoffUserInfo)
        XCTAssertEqual(SingleInstance.handoffNotification.rawValue, "com.badpx.macfan.showSettings")
    }

    func testMissingBundleIdentifierDoesNotMatchOtherProcesses() {
        let peers = [
            SingleInstancePeer(bundleIdentifier: nil, processIdentifier: 10),
            SingleInstancePeer(bundleIdentifier: "", processIdentifier: 11),
            SingleInstancePeer(bundleIdentifier: bundle, processIdentifier: 12),
        ]
        XCTAssertFalse(SingleInstance.shouldYield(
            bundleIdentifier: nil, currentPID: 42, peers: peers, arguments: []))
        XCTAssertFalse(SingleInstance.shouldYield(
            bundleIdentifier: "", currentPID: 42, peers: peers, arguments: []))
    }
}
