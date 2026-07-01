import XCTest
@testable import NowPlayingCore

final class MarqueeTests: XCTestCase {
    // textWidth 200, viewWidth 100 -> distance 100; speed 100 -> legTime 1s; pause 0.5s.
    // cycle = 2*0.5 + 2*1 = 3s.
    private func offset(_ elapsed: TimeInterval) -> CGFloat {
        Marquee.offset(elapsed: elapsed, textWidth: 200, viewWidth: 100,
                       speed: 100, pause: 0.5)
    }

    func testNoOffsetWhenTextFits() {
        XCTAssertEqual(Marquee.offset(elapsed: 5, textWidth: 80, viewWidth: 100,
                                      speed: 100, pause: 0.5), 0)
    }

    func testZeroSpeedReturnsZero() {
        XCTAssertEqual(Marquee.offset(elapsed: 5, textWidth: 200, viewWidth: 100,
                                      speed: 0, pause: 0.5), 0)
    }

    func testOpeningPauseIsZero() {
        XCTAssertEqual(offset(0), 0, accuracy: 0.0001)
    }

    func testMidFirstLeg() {
        // t = pause + legTime/2 = 1.0 -> half of distance
        XCTAssertEqual(offset(1.0), 50, accuracy: 0.0001)
    }

    func testFarEnd() {
        // t = pause + legTime = 1.5 -> full distance (start of end pause)
        XCTAssertEqual(offset(1.5), 100, accuracy: 0.0001)
    }

    func testReturnLegMidpoint() {
        // t = 2*pause + legTime + legTime/2 = 2.5 -> half distance on the way back
        XCTAssertEqual(offset(2.5), 50, accuracy: 0.0001)
    }

    func testPeriodic() {
        XCTAssertEqual(offset(0.7), offset(3.7), accuracy: 0.0001)
    }
}
