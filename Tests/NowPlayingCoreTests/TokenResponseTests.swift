import XCTest
@testable import NowPlayingCore

final class TokenResponseTests: XCTestCase {
    func testDecodesTokenResponse() throws {
        let json = """
        {"access_token":"AT","refresh_token":"RT","expires_in":3600,"token_type":"Bearer"}
        """
        let token = try JSONDecoder().decode(TokenResponse.self, from: Data(json.utf8))
        XCTAssertEqual(token, TokenResponse(accessToken: "AT", refreshToken: "RT", expiresIn: 3600))
    }

    func testRefreshTokenOptional() throws {
        let json = #"{"access_token":"AT2","expires_in":3600}"#
        let token = try JSONDecoder().decode(TokenResponse.self, from: Data(json.utf8))
        XCTAssertNil(token.refreshToken)
        XCTAssertEqual(token.accessToken, "AT2")
    }
}
