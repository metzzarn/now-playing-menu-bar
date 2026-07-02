import Foundation
import CoreGraphics

/// Default values for every preference, kept in one place rather than spread
/// across the `Preferences` accessors.
public enum PreferenceDefaults {
    public static let refreshInterval: TimeInterval = 3

    public static let progressBarEnabled = true
    public static let progressBarThickness: Double = 2
    public static let progressBarColorHex = "#1DB954FF"

    public static let scrollEnabled = true
    public static let scrollSpeed: Double = 20
    public static let scrollPauseAtEnds: Double = 1

    public static let useStaticWidth = false
    public static let staticWidth: Double = 150
    public static let maxWidth: Double = 200

    public static let textAlignment: MenuBarTextAlignment = .left
    public static let trackTemplate = "<artists> - <title> <(year)>"

    public static let popupOpacity: Double = 1
    public static let minPopupOpacity: Double = 0.5
}
