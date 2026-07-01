import Foundation

public enum SpotifyClientError: Error, Equatable {
    case unauthorized
    case unexpectedStatus(Int)
}

public struct SpotifyClient {
    private let http: HTTPFetching
    private let tokenProvider: () async throws -> String

    public init(http: HTTPFetching, tokenProvider: @escaping () async throws -> String) {
        self.http = http
        self.tokenProvider = tokenProvider
    }

    public func currentlyPlaying() async throws -> NowPlaying? {
        let token = try await tokenProvider()
        var request = URLRequest(
            url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyClientError.unexpectedStatus(-1)
        }
        switch http.statusCode {
        case 204: return nil
        case 401: throw SpotifyClientError.unauthorized
        case 200: return try Self.parse(data)
        default: throw SpotifyClientError.unexpectedStatus(http.statusCode)
        }
    }

    static func parse(_ data: Data) throws -> NowPlaying? {
        struct Artist: Decodable { let name: String }
        struct Item: Decodable { let name: String; let artists: [Artist] }
        struct Payload: Decodable { let item: Item? }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let item = payload.item else { return nil }
        return NowPlaying(artist: item.artists.first?.name ?? "", track: item.name)
    }
}
