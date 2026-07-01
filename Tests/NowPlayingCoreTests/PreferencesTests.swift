import XCTest
@testable import NowPlayingCore

final class PreferencesTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.nowplayingbar.\(UUID().uuidString)")!
    }

    func testDefaultInterval() {
        XCTAssertEqual(Preferences(defaults: makeDefaults()).refreshInterval, 5)
    }

    func testClientIDRoundTrips() {
        var prefs = Preferences(defaults: makeDefaults())
        XCTAssertNil(prefs.clientID)
        prefs.clientID = "abc123"
        XCTAssertEqual(prefs.clientID, "abc123")
    }

    func testIntervalRoundTrips() {
        var prefs = Preferences(defaults: makeDefaults())
        prefs.refreshInterval = 10
        XCTAssertEqual(prefs.refreshInterval, 10)
    }
}
