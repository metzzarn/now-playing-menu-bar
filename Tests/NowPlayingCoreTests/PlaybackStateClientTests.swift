import XCTest
@testable import NowPlayingCore

final class PlaybackStateClientTests: XCTestCase {
    private func client(_ mock: MockHTTP) -> SpotifyClient {
        SpotifyClient(http: mock, tokenProvider: { "t" })
    }

    func testParsesPlaybackState() async throws {
        let json = """
        {"is_playing":true,"progress_ms":12000,
         "item":{"name":"Idioteque","duration_ms":312000,
           "artists":[{"name":"Radiohead"}],
           "album":{"name":"Kid A","images":[{"url":"https://img/1"}]}}}
        """
        let state = try await client(MockHTTP(status: 200, body: Data(json.utf8))).playbackState()
        XCTAssertEqual(state, PlaybackState(track: "Idioteque", artist: "Radiohead",
            album: "Kid A", artworkURL: URL(string: "https://img/1"),
            isPlaying: true, progressMs: 12000, durationMs: 312000))
    }

    func test204ReturnsNil() async throws {
        let state = try await client(MockHTTP(status: 204)).playbackState()
        XCTAssertNil(state)
    }

    func testMissingArtworkYieldsNilURL() async throws {
        let json = """
        {"is_playing":false,"progress_ms":0,
         "item":{"name":"X","duration_ms":1000,"artists":[{"name":"Y"}],
           "album":{"name":"Z","images":[]}}}
        """
        let state = try await client(MockHTTP(status: 200, body: Data(json.utf8))).playbackState()
        XCTAssertNil(state?.artworkURL)
    }

    func testNextIssuesPost() async throws {
        let mock = MockHTTP(status: 204)
        try await client(mock).next()
        XCTAssertEqual(mock.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mock.lastRequest?.url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/next")
    }

    func testPlayIssuesPut() async throws {
        let mock = MockHTTP(status: 204)
        try await client(mock).play()
        XCTAssertEqual(mock.lastRequest?.httpMethod, "PUT")
        XCTAssertEqual(mock.lastRequest?.url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/play")
    }

    func testControl401Throws() async {
        do {
            try await client(MockHTTP(status: 401)).pause()
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? SpotifyClientError, .unauthorized)
        }
    }
}
