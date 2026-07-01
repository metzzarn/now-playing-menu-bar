import XCTest
@testable import NowPlayingCore

final class PKCETests: XCTestCase {
    func testChallengeMatchesRFC7636Vector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        XCTAssertEqual(PKCE.challenge(for: verifier),
                       "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testVerifierHasRequestedLength() {
        XCTAssertEqual(PKCE.makeVerifier(length: 64).count, 64)
    }

    func testVerifierUsesOnlyUnreservedChars() {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        XCTAssertTrue(PKCE.makeVerifier().allSatisfy { allowed.contains($0) })
    }

    func testInitPopulatesBothFields() {
        let pkce = PKCE()
        XCTAssertFalse(pkce.verifier.isEmpty)
        XCTAssertEqual(pkce.challenge, PKCE.challenge(for: pkce.verifier))
    }
}
