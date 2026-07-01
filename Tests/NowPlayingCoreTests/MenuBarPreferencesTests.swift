import XCTest
@testable import NowPlayingCore

final class MenuBarPreferencesTests: XCTestCase {
    private func makePrefs() -> Preferences {
        Preferences(defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)
    }

    func testDefaultsInMenuBarStyle() {
        let style = makePrefs().menuBarStyle
        XCTAssertFalse(style.progressBarEnabled)
        XCTAssertEqual(style.thickness, 2)
        XCTAssertEqual(style.colorHex, "#1DB954FF")
        XCTAssertFalse(style.scrollEnabled)
        XCTAssertEqual(style.scrollSpeed, 20)
        XCTAssertEqual(style.maxWidth, 150)
        XCTAssertEqual(style.pauseAtEnds, 1.5)
    }

    func testRoundTrips() {
        var prefs = makePrefs()
        prefs.progressBarEnabled = true
        prefs.progressBarColorHex = "#FF0000FF"
        prefs.scrollEnabled = true
        prefs.scrollSpeed = 60
        prefs.scrollMaxWidth = 200
        prefs.scrollPauseAtEnds = 2
        let style = prefs.menuBarStyle
        XCTAssertTrue(style.progressBarEnabled)
        XCTAssertEqual(style.colorHex, "#FF0000FF")
        XCTAssertTrue(style.scrollEnabled)
        XCTAssertEqual(style.scrollSpeed, 60)
        XCTAssertEqual(style.maxWidth, 200)
        XCTAssertEqual(style.pauseAtEnds, 2)
    }

    func testStaticWidthDefaultsAndRoundTrips() {
        var prefs = makePrefs()
        let style = prefs.menuBarStyle
        XCTAssertFalse(style.useStaticWidth)
        XCTAssertEqual(style.staticWidth, 150)
        XCTAssertEqual(style.widthCap, style.maxWidth)

        prefs.useStaticWidth = true
        prefs.staticWidth = 120
        let updated = prefs.menuBarStyle
        XCTAssertTrue(updated.useStaticWidth)
        XCTAssertEqual(updated.staticWidth, 120)
        XCTAssertEqual(updated.widthCap, 120)
    }

    func testAlignmentDefaultsToLeftAndRoundTrips() {
        var prefs = makePrefs()
        XCTAssertEqual(prefs.menuBarStyle.alignment, .left)
        prefs.textAlignment = .center
        XCTAssertEqual(prefs.menuBarStyle.alignment, .center)
    }

    func testThicknessClampedToRange() {
        var prefs = makePrefs()
        prefs.progressBarThickness = 99
        XCTAssertEqual(prefs.menuBarStyle.thickness, 4)
        prefs.progressBarThickness = 0.1
        XCTAssertEqual(prefs.menuBarStyle.thickness, 1)
    }
}
