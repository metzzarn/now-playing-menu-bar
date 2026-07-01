import XCTest
@testable import NowPlayingCore

final class PreferencesTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.nowplayingbar.\(UUID().uuidString)")!
    }

    func testDefaultInterval() {
        XCTAssertEqual(Preferences(defaults: makeDefaults()).refreshInterval, 3)
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

    func testTrackTemplateDefaultsWhenUnset() {
        XCTAssertEqual(Preferences(defaults: makeDefaults()).trackTemplate,
                       Preferences.defaultTrackTemplate)
    }

    func testTrackTemplateFallsBackWhenInvalid() {
        var prefs = Preferences(defaults: makeDefaults())
        prefs.trackTemplate = "<foo> - <title>"  // unknown variable
        XCTAssertEqual(prefs.trackTemplate, Preferences.defaultTrackTemplate)
    }

    func testTrackTemplateRoundTripsWhenValid() {
        var prefs = Preferences(defaults: makeDefaults())
        prefs.trackTemplate = "<title> (<year>)"
        XCTAssertEqual(prefs.trackTemplate, "<title> (<year>)")
    }
}
