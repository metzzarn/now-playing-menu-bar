public struct NowPlaying: Equatable {
    public let artist: String
    public let track: String

    public init(artist: String, track: String) {
        self.artist = artist
        self.track = track
    }
}

public enum DisplayState: Equatable {
    case loggedOut
    case idle
    case playing(NowPlaying)
}
