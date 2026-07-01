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

    public func playbackState() async throws -> PlaybackState? {
        let token = try await tokenProvider()
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyClientError.unexpectedStatus(-1)
        }
        switch http.statusCode {
        case 204: return nil
        case 401: throw SpotifyClientError.unauthorized
        case 200: return try Self.parseState(data)
        default: throw SpotifyClientError.unexpectedStatus(http.statusCode)
        }
    }

    public func next() async throws { try await control(method: "POST", path: "next") }
    public func previous() async throws { try await control(method: "POST", path: "previous") }
    public func play() async throws { try await control(method: "PUT", path: "play") }
    public func pause() async throws { try await control(method: "PUT", path: "pause") }

    private func control(method: String, path: String) async throws {
        let token = try await tokenProvider()
        var request = URLRequest(
            url: URL(string: "https://api.spotify.com/v1/me/player/\(path)")!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyClientError.unexpectedStatus(-1)
        }
        switch http.statusCode {
        case 200...299: return
        case 401: throw SpotifyClientError.unauthorized
        default: throw SpotifyClientError.unexpectedStatus(http.statusCode)
        }
    }

    static func parseState(_ data: Data) throws -> PlaybackState? {
        struct Image: Decodable { let url: String }
        struct Album: Decodable {
            let name: String
            let images: [Image]
            let releaseDate: String?
            enum CodingKeys: String, CodingKey {
                case name, images
                case releaseDate = "release_date"
            }
        }
        struct Artist: Decodable { let name: String }
        struct Item: Decodable {
            let name: String
            let durationMs: Int
            let artists: [Artist]
            let album: Album
            enum CodingKeys: String, CodingKey {
                case name, artists, album
                case durationMs = "duration_ms"
            }
        }
        struct Payload: Decodable {
            let isPlaying: Bool
            let progressMs: Int?
            let item: Item?
            enum CodingKeys: String, CodingKey {
                case item
                case isPlaying = "is_playing"
                case progressMs = "progress_ms"
            }
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let item = payload.item else { return nil }
        let names = item.artists.map(\.name)
        let year = item.album.releaseDate.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
        return PlaybackState(
            track: item.name,
            artist: names.first ?? "",
            artists: names,
            album: item.album.name,
            year: year,
            artworkURL: item.album.images.first.flatMap { URL(string: $0.url) },
            isPlaying: payload.isPlaying,
            progressMs: payload.progressMs ?? 0,
            durationMs: item.durationMs)
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
