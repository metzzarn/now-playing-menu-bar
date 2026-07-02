import XCTest
@testable import NowPlayingCore

final class ThemeTests: XCTestCase {
    func testDefaultColorsMatchDefaultTheme() {
        // The app's default: system colors (nil) + Spotify-green bar.
        let theme = Theme.matching(background: nil, text: nil, menuBarText: nil,
                                   progressBarColor: "#1DB954FF", progressBarBackground: nil)
        XCTAssertEqual(theme?.name, "Default")
    }

    func testPresetMatches() {
        let s = Theme.spotify
        let theme = Theme.matching(background: s.background, text: s.text,
                                   menuBarText: s.menuBarText, progressBarColor: s.progressBarColor,
                                   progressBarBackground: s.progressBarBackground)
        XCTAssertEqual(theme?.name, "Spotify")
    }

    func testCaseInsensitiveMatch() {
        let theme = Theme.matching(background: "#191414ff", text: "#ffffffff",
                                   menuBarText: "#1db954ff", progressBarColor: "#1db954ff",
                                   progressBarBackground: "#404040ff")
        XCTAssertEqual(theme?.name, "Spotify")
    }

    func testCustomReturnsNil() {
        let theme = Theme.matching(background: "#123456FF", text: nil, menuBarText: nil,
                                   progressBarColor: "#1DB954FF", progressBarBackground: nil)
        XCTAssertNil(theme)
    }
}
