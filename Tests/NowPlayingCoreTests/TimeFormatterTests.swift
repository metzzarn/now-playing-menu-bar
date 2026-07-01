import XCTest
@testable import NowPlayingCore

final class TimeFormatterTests: XCTestCase {
    func testZero() { XCTAssertEqual(TimeFormatter.string(fromMs: 0), "0:00") }
    func testSevenSeconds() { XCTAssertEqual(TimeFormatter.string(fromMs: 7000), "0:07") }
    func testMinuteRollover() { XCTAssertEqual(TimeFormatter.string(fromMs: 60000), "1:00") }
    func testMinutesAndSeconds() { XCTAssertEqual(TimeFormatter.string(fromMs: 225000), "3:45") }
    func testNegativeClampsToZero() { XCTAssertEqual(TimeFormatter.string(fromMs: -5000), "0:00") }
    func testTwoDigitMinutes() { XCTAssertEqual(TimeFormatter.string(fromMs: 723000), "12:03") }
}
