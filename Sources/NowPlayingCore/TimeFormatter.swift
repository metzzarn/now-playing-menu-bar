public enum TimeFormatter {
    public static func string(fromMs ms: Int) -> String {
        let totalSeconds = max(0, ms) / 1000
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}
