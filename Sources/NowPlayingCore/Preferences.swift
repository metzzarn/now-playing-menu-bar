import Foundation
import CoreGraphics

public struct Preferences {
    private let defaults: UserDefaults
    private enum Key {
        static let clientID = "clientID"
        static let refreshInterval = "refreshInterval"
        static let grantedScope = "grantedScope"
        static let progressBarEnabled = "progressBarEnabled"
        static let progressBarThickness = "progressBarThickness"
        static let progressBarColorHex = "progressBarColorHex"
        static let scrollEnabled = "scrollEnabled"
        static let scrollSpeed = "scrollSpeed"
        static let useStaticWidth = "useStaticWidth"
        static let staticWidth = "staticWidth"
        static let scrollMaxWidth = "scrollMaxWidth"
        static let scrollPauseAtEnds = "scrollPauseAtEnds"
        static let textAlignment = "textAlignment"
        static let trackTemplate = "trackTemplate"
        static let appBackgroundColorHex = "appBackgroundColorHex"
        static let appTextColorHex = "appTextColorHex"
        static let menuBarTextColorHex = "menuBarTextColorHex"
        static let progressBarBackgroundColorHex = "progressBarBackgroundColorHex"
    }

    private static let defaultColorHex = "#1DB954FF"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var clientID: String? {
        get {
            guard let value = defaults.string(forKey: Key.clientID), !value.isEmpty else {
                return nil
            }
            return value
        }
        set { defaults.set(newValue, forKey: Key.clientID) }
    }

    public var refreshInterval: TimeInterval {
        get {
            let stored = defaults.double(forKey: Key.refreshInterval)
            return stored == 0 ? 3 : stored
        }
        set { defaults.set(newValue, forKey: Key.refreshInterval) }
    }

    public var grantedScope: String? {
        get { defaults.string(forKey: Key.grantedScope) }
        set { defaults.set(newValue, forKey: Key.grantedScope) }
    }

    // MARK: - Menu bar appearance

    public var progressBarEnabled: Bool {
        get { defaults.bool(forKey: Key.progressBarEnabled) }
        set { defaults.set(newValue, forKey: Key.progressBarEnabled) }
    }

    public var progressBarThickness: Double {
        get { (defaults.object(forKey: Key.progressBarThickness) as? Double) ?? 2 }
        set { defaults.set(newValue, forKey: Key.progressBarThickness) }
    }

    public var progressBarColorHex: String {
        get { defaults.string(forKey: Key.progressBarColorHex) ?? Self.defaultColorHex }
        set { defaults.set(newValue, forKey: Key.progressBarColorHex) }
    }

    public var scrollEnabled: Bool {
        get { defaults.bool(forKey: Key.scrollEnabled) }
        set { defaults.set(newValue, forKey: Key.scrollEnabled) }
    }

    public var scrollSpeed: Double {
        get { (defaults.object(forKey: Key.scrollSpeed) as? Double) ?? 20 }
        set { defaults.set(newValue, forKey: Key.scrollSpeed) }
    }

    public var useStaticWidth: Bool {
        get { defaults.bool(forKey: Key.useStaticWidth) }
        set { defaults.set(newValue, forKey: Key.useStaticWidth) }
    }

    public var staticWidth: Double {
        get { (defaults.object(forKey: Key.staticWidth) as? Double) ?? 150 }
        set { defaults.set(newValue, forKey: Key.staticWidth) }
    }

    public var scrollMaxWidth: Double {
        get { (defaults.object(forKey: Key.scrollMaxWidth) as? Double) ?? 150 }
        set { defaults.set(newValue, forKey: Key.scrollMaxWidth) }
    }

    public var scrollPauseAtEnds: Double {
        get { (defaults.object(forKey: Key.scrollPauseAtEnds) as? Double) ?? 1 }
        set { defaults.set(newValue, forKey: Key.scrollPauseAtEnds) }
    }

    public var textAlignment: MenuBarTextAlignment {
        get {
            (defaults.string(forKey: Key.textAlignment)).flatMap(MenuBarTextAlignment.init) ?? .left
        }
        set { defaults.set(newValue.rawValue, forKey: Key.textAlignment) }
    }

    public static let defaultTrackTemplate = "<artists> - <title> <(year)>"

    // Color settings; nil means "use the system color".

    public var appBackgroundColorHex: String? {
        get { defaults.string(forKey: Key.appBackgroundColorHex) }
        set { defaults.set(newValue, forKey: Key.appBackgroundColorHex) }
    }

    public var appTextColorHex: String? {
        get { defaults.string(forKey: Key.appTextColorHex) }
        set { defaults.set(newValue, forKey: Key.appTextColorHex) }
    }

    public var menuBarTextColorHex: String? {
        get { defaults.string(forKey: Key.menuBarTextColorHex) }
        set { defaults.set(newValue, forKey: Key.menuBarTextColorHex) }
    }

    public var progressBarBackgroundColorHex: String? {
        get { defaults.string(forKey: Key.progressBarBackgroundColorHex) }
        set { defaults.set(newValue, forKey: Key.progressBarBackgroundColorHex) }
    }

    public var trackTemplate: String {
        get {
            guard let value = defaults.string(forKey: Key.trackTemplate),
                  !value.isEmpty,
                  TrackTemplate.validate(value) == nil else {
                return Self.defaultTrackTemplate
            }
            return value
        }
        set { defaults.set(newValue, forKey: Key.trackTemplate) }
    }

    public var menuBarStyle: MenuBarStyle {
        MenuBarStyle(
            progressBarEnabled: progressBarEnabled,
            thickness: CGFloat(min(4, max(1, progressBarThickness))),
            colorHex: progressBarColorHex,
            scrollEnabled: scrollEnabled,
            scrollSpeed: CGFloat(max(0, scrollSpeed)),
            useStaticWidth: useStaticWidth,
            staticWidth: CGFloat(max(40, staticWidth)),
            maxWidth: CGFloat(max(40, scrollMaxWidth)),
            pauseAtEnds: max(0, scrollPauseAtEnds),
            alignment: textAlignment,
            textColorHex: menuBarTextColorHex,
            barBackgroundColorHex: progressBarBackgroundColorHex)
    }
}
