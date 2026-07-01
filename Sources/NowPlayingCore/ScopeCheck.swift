public enum ScopeCheck {
    public static func needsReauth(granted: String?, required: String) -> Bool {
        granted != required
    }
}
