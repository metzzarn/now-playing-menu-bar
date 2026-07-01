public enum TitleFormatter {
    public static let maxLength = 30

    public static func title(for state: DisplayState) -> String {
        switch state {
        case .loggedOut:
            return "Login"
        case .idle:
            return "♪"
        case .playing(let np):
            return truncate("\(np.artist) — \(np.track)", to: maxLength)
        }
    }

    static func truncate(_ s: String, to max: Int) -> String {
        guard s.count > max else { return s }
        let end = s.index(s.startIndex, offsetBy: max - 1)
        return String(s[..<end]) + "…"
    }
}
