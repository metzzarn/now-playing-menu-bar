import XCTest
@testable import NowPlayingCore

final class LoopbackServerTests: XCTestCase {
    func testExtractsCodeAndStateFromRequestLine() {
        let request = "GET /callback?code=abc123&state=xyz HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        let callback = LoopbackServer.extractCallback(from: request)
        XCTAssertEqual(callback, OAuthCallback(code: "abc123", state: "xyz"))
    }

    func testExtractsCodeWhenStateMissing() {
        let request = "GET /callback?code=abc123 HTTP/1.1\r\n\r\n"
        let callback = LoopbackServer.extractCallback(from: request)
        XCTAssertEqual(callback, OAuthCallback(code: "abc123", state: nil))
    }

    func testReturnsNilWhenNoCode() {
        let request = "GET /callback?error=access_denied HTTP/1.1\r\n\r\n"
        XCTAssertNil(LoopbackServer.extractCallback(from: request))
    }
}
