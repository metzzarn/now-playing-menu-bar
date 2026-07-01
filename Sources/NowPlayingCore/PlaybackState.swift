import Foundation

public struct PlaybackState: Equatable {
    public let track: String
    public let artist: String
    public let album: String
    public let artworkURL: URL?
    public let isPlaying: Bool
    public let progressMs: Int
    public let durationMs: Int

    public init(track: String, artist: String, album: String, artworkURL: URL?,
                isPlaying: Bool, progressMs: Int, durationMs: Int) {
        self.track = track
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.isPlaying = isPlaying
        self.progressMs = progressMs
        self.durationMs = durationMs
    }
}
