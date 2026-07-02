import Foundation

/// A named preset for the Style-tab colors. Optional hexes (`nil`) mean "use the
/// system color"; `progressBarColor` is always concrete.
public struct Theme: Equatable {
    public let name: String
    public let background: String?
    public let text: String?
    public let menuBarText: String?
    public let progressBarColor: String
    public let progressBarBackground: String?

    public init(name: String, background: String?, text: String?, menuBarText: String?,
                progressBarColor: String, progressBarBackground: String?) {
        self.name = name
        self.background = background
        self.text = text
        self.menuBarText = menuBarText
        self.progressBarColor = progressBarColor
        self.progressBarBackground = progressBarBackground
    }

    public static let all: [Theme] = [.default, .spotify, .dark, .light, .midnight, .solarized]

    /// The original look: system colors with a Spotify-green progress bar.
    public static let `default` = Theme(
        name: "Default", background: nil, text: nil, menuBarText: nil,
        progressBarColor: "#1DB954FF", progressBarBackground: nil)

    public static let spotify = Theme(
        name: "Spotify", background: "#191414FF", text: "#FFFFFFFF", menuBarText: "#1DB954FF",
        progressBarColor: "#1DB954FF", progressBarBackground: "#404040FF")

    public static let dark = Theme(
        name: "Dark", background: "#1E1E1EFF", text: "#FFFFFFFF", menuBarText: "#FFFFFFFF",
        progressBarColor: "#0A84FFFF", progressBarBackground: "#3A3A3AFF")

    public static let light = Theme(
        name: "Light", background: "#FFFFFFFF", text: "#000000FF", menuBarText: "#000000FF",
        progressBarColor: "#0A84FFFF", progressBarBackground: "#D0D0D0FF")

    public static let midnight = Theme(
        name: "Midnight", background: "#0B1021FF", text: "#C0CAF5FF", menuBarText: "#7AA2F7FF",
        progressBarColor: "#7AA2F7FF", progressBarBackground: "#2A2E45FF")

    public static let solarized = Theme(
        name: "Solarized", background: "#002B36FF", text: "#93A1A1FF", menuBarText: "#B58900FF",
        progressBarColor: "#268BD2FF", progressBarBackground: "#073642FF")

    /// Returns the theme whose colors equal the given values (case-insensitive), or
    /// nil when the values don't match any preset ("Custom").
    public static func matching(background: String?, text: String?, menuBarText: String?,
                                progressBarColor: String,
                                progressBarBackground: String?) -> Theme? {
        func norm(_ s: String?) -> String? { s?.uppercased() }
        return all.first {
            norm($0.background) == norm(background)
                && norm($0.text) == norm(text)
                && norm($0.menuBarText) == norm(menuBarText)
                && norm($0.progressBarColor) == norm(progressBarColor)
                && norm($0.progressBarBackground) == norm(progressBarBackground)
        }
    }
}
