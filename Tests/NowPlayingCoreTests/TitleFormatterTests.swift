import XCTest
@testable import NowPlayingCore

final class TitleFormatterTests: XCTestCase {
    func testLoggedOut() {
        XCTAssertEqual(TitleFormatter.title(for: .loggedOut), "Login")
    }

    func testIdle() {
        XCTAssertEqual(TitleFormatter.title(for: .idle), "♪")
    }

    func testPlayingShort() {
        let np = NowPlaying(artist: "Radiohead", track: "Idioteque")
        XCTAssertEqual(TitleFormatter.title(for: .playing(np)), "Radiohead — Idioteque")
    }

    func testPlayingTruncatesLongTitle() {
        let np = NowPlaying(artist: "A Very Long Artist Name Here",
                            track: "And An Even Longer Track Title")
        let title = TitleFormatter.title(for: .playing(np))
        XCTAssertEqual(title.count, TitleFormatter.maxLength)
        XCTAssertTrue(title.hasSuffix("…"))
    }
}
