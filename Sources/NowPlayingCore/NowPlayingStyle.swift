/// Layout style for the now-playing popup.
public enum NowPlayingStyle: String, CaseIterable, Sendable {
    /// Album art on the left, details on the right (the original layout).
    case simple
    /// Larger album art centered on top, details stacked below.
    case largeArt

    public var displayName: String {
        switch self {
        case .simple: return "Simple"
        case .largeArt: return "Large Art"
        }
    }
}
