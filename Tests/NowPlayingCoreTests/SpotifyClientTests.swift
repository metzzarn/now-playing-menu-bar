import XCTest
@testable import NowPlayingCore

final class SpotifyClientTests: XCTestCase {
    private func client(_ mock: MockHTTP) -> SpotifyClient {
        SpotifyClient(http: mock, tokenProvider: { "test-token" })
    }

    func testParsesPlayingTrack() async throws {
        let json = """
        {"item":{"name":"Idioteque","artists":[{"name":"Radiohead"}]}}
        """
        let np = try await client(MockHTTP(status: 200, body: Data(json.utf8)))
            .currentlyPlaying()
        XCTAssertEqual(np, NowPlaying(artist: "Radiohead", track: "Idioteque"))
    }

    func test204ReturnsNil() async throws {
        let np = try await client(MockHTTP(status: 204)).currentlyPlaying()
        XCTAssertNil(np)
    }

    func test401ThrowsUnauthorized() async {
        do {
            _ = try await client(MockHTTP(status: 401)).currentlyPlaying()
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? SpotifyClientError, .unauthorized)
        }
    }

    func testSendsBearerToken() async throws {
        let mock = MockHTTP(status: 204)
        _ = try await client(mock).currentlyPlaying()
        XCTAssertEqual(mock.lastRequest?.value(forHTTPHeaderField: "Authorization"),
                       "Bearer test-token")
    }
}
