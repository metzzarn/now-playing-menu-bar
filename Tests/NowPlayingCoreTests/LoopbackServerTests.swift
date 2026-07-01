import XCTest
@testable import NowPlayingCore

final class LoopbackServerTests: XCTestCase {
    func testExtractsCodeFromRequestLine() {
        let request = "GET /callback?code=abc123&state=xyz HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        XCTAssertEqual(LoopbackServer.extractCode(from: request), "abc123")
    }

    func testReturnsNilWhenNoCode() {
        let request = "GET /callback?error=access_denied HTTP/1.1\r\n\r\n"
        XCTAssertNil(LoopbackServer.extractCode(from: request))
    }
}
