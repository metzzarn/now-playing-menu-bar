import XCTest
@testable import NowPlayingCore

final class PreferencesTests: XCTestCase {
    private func makeStore() -> PreferencesStore {
        InMemoryPreferencesStore()
    }

    func testDefaultInterval() {
        XCTAssertEqual(Preferences(store: makeStore()).refreshInterval,
                       PreferenceDefaults.refreshInterval)
    }

    func testClientIDRoundTrips() {
        var prefs = Preferences(store: makeStore())
        XCTAssertNil(prefs.clientID)
        prefs.clientID = "abc123"
        XCTAssertEqual(prefs.clientID, "abc123")
    }

    func testIntervalRoundTrips() {
        var prefs = Preferences(store: makeStore())
        prefs.refreshInterval = 10
        XCTAssertEqual(prefs.refreshInterval, 10)
    }

    func testTrackTemplateDefaultsWhenUnset() {
        XCTAssertEqual(Preferences(store: makeStore()).trackTemplate,
                       Preferences.defaultTrackTemplate)
    }

    func testTrackTemplateFallsBackWhenInvalid() {
        var prefs = Preferences(store: makeStore())
        prefs.trackTemplate = "<foo> - <title>"  // unknown variable
        XCTAssertEqual(prefs.trackTemplate, Preferences.defaultTrackTemplate)
    }

    func testPopupOpacityDefaultsToFull() {
        XCTAssertEqual(Preferences(store: makeStore()).popupOpacity, 1)
    }

    func testPopupOpacityClampsToMinimum() {
        var prefs = Preferences(store: makeStore())
        prefs.popupOpacity = 0.1
        XCTAssertEqual(prefs.popupOpacity, PreferenceDefaults.minPopupOpacity)
        prefs.popupOpacity = 0.7
        XCTAssertEqual(prefs.popupOpacity, 0.7)
    }

    func testTrackTemplateRoundTripsWhenValid() {
        var prefs = Preferences(store: makeStore())
        prefs.trackTemplate = "<title> (<year>)"
        XCTAssertEqual(prefs.trackTemplate, "<title> (<year>)")
    }

    func testNowPlayingStyleDefaultsToSimple() {
        XCTAssertEqual(Preferences(store: makeStore()).nowPlayingStyle, .simple)
    }

    func testNowPlayingStyleRoundTrips() {
        var prefs = Preferences(store: makeStore())
        prefs.nowPlayingStyle = .largeArt
        XCTAssertEqual(prefs.nowPlayingStyle, .largeArt)
    }
}
