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
}
