import XCTest
@testable import NowPlayingCore

final class ScopeCheckTests: XCTestCase {
    func testNeedsReauthWhenNil() {
        XCTAssertTrue(ScopeCheck.needsReauth(granted: nil, required: "a b"))
    }

    func testNoReauthWhenEqual() {
        XCTAssertFalse(ScopeCheck.needsReauth(granted: "a b", required: "a b"))
    }

    func testNeedsReauthWhenDiffers() {
        XCTAssertTrue(ScopeCheck.needsReauth(granted: "a", required: "a b"))
    }

    func testGrantedScopeRoundTrips() {
        var prefs = Preferences(defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)
        XCTAssertNil(prefs.grantedScope)
        prefs.grantedScope = "a b"
        XCTAssertEqual(prefs.grantedScope, "a b")
    }
}
