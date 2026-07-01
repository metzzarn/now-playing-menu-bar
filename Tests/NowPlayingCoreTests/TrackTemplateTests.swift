import XCTest
@testable import NowPlayingCore

final class TrackTemplateTests: XCTestCase {
    private let values: [TrackVariable: String] = [
        .title: "Idioteque",
        .artist: "Radiohead",
        .artists: "Radiohead, Thom Yorke",
        .album: "Kid A",
        .year: "2000",
    ]

    private func render(_ template: String, _ values: [TrackVariable: String]? = nil) -> String {
        TrackTemplate.render(template, values: values ?? self.values)
    }

    func testPlainTemplate() {
        XCTAssertEqual(render("<artist> - <title>"), "Radiohead - Idioteque")
    }

    func testLiteralTextPreserved() {
        XCTAssertEqual(render("<title> [<album>]"), "Idioteque [Kid A]")
    }

    func testAllArtists() {
        XCTAssertEqual(render("<artists>"), "Radiohead, Thom Yorke")
    }

    func testLongestMatchArtistsBeatsArtist() {
        // Ensures "<artists>" resolves to the artists variable, not "artist" + "s".
        XCTAssertEqual(render("<artists>"), "Radiohead, Thom Yorke")
    }

    func testConditionalDecorationShownWhenPresent() {
        XCTAssertEqual(render("<title> <(year)>"), "Idioteque (2000)")
    }

    func testConditionalDecorationHiddenWhenMissing() {
        var v = values
        v[.year] = ""
        XCTAssertEqual(render("<title> <(year)>", v), "Idioteque ")
    }

    func testLiteralParensAlwaysShown() {
        var v = values
        v[.year] = ""
        // Parens are literal here, so they remain even when year is empty.
        XCTAssertEqual(render("<title> (<year>)", v), "Idioteque ()")
    }

    func testValidTemplateReturnsNil() {
        XCTAssertNil(TrackTemplate.validate("<artist> — <title> <(year)>"))
    }

    func testUnknownVariableIsInvalid() {
        XCTAssertEqual(TrackTemplate.validate("<foo> - <title>"), "Unknown variable: <foo>")
    }

    func testUnclosedBracketIsInvalid() {
        XCTAssertEqual(TrackTemplate.validate("<artist"), "Unclosed '<'")
    }
}
