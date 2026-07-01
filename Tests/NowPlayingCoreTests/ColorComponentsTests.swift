import XCTest
@testable import NowPlayingCore

final class ColorComponentsTests: XCTestCase {
    func testParsesRRGGBBWithDefaultAlpha() {
        let c = ColorComponents.parse(hex: "#1DB954")
        XCTAssertEqual(c, ColorComponents(red: 29/255, green: 185/255, blue: 84/255, alpha: 1))
    }

    func testParsesRRGGBBAA() {
        let c = ColorComponents.parse(hex: "#1DB95480")
        XCTAssertEqual(c, ColorComponents(red: 29/255, green: 185/255, blue: 84/255, alpha: 128/255))
    }

    func testWithoutLeadingHash() {
        XCTAssertEqual(ColorComponents.parse(hex: "FFFFFF"),
                       ColorComponents(red: 1, green: 1, blue: 1, alpha: 1))
    }

    func testCaseInsensitive() {
        XCTAssertEqual(ColorComponents.parse(hex: "#1db954"),
                       ColorComponents.parse(hex: "#1DB954"))
    }

    func testRejectsBadLength() {
        XCTAssertNil(ColorComponents.parse(hex: "#123"))
    }

    func testRejectsNonHex() {
        XCTAssertNil(ColorComponents.parse(hex: "#GGGGGG"))
    }

    func testRejectsSignCharacter() {
        XCTAssertNil(ColorComponents.parse(hex: "+1B954"))
        XCTAssertNil(ColorComponents.parse(hex: "-1B954A"))
    }
}
