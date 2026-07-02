import Foundation
import CoreGraphics

public struct Preferences {
    private let store: PreferencesStore
    private enum Key {
        static let clientID = "clientID"
        static let refreshInterval = "refreshInterval"
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
    public static let defaultTrackTemplate = "<artists> - <title> <(year)>"

    public init(store: PreferencesStore = FilePreferencesStore()) {
        self.store = store
    }

    public var clientID: String? {
        get {
            guard let value = store.string(forKey: Key.clientID), !value.isEmpty else { return nil }
            return value
        }
        set { store.setString(newValue, forKey: Key.clientID) }
    }

    public var refreshInterval: TimeInterval {
        get { store.double(forKey: Key.refreshInterval) ?? 3 }
        set { store.setDouble(newValue, forKey: Key.refreshInterval) }
    }

    // MARK: - Menu bar appearance

    public var progressBarEnabled: Bool {
        get { store.bool(forKey: Key.progressBarEnabled) ?? true }
        set { store.setBool(newValue, forKey: Key.progressBarEnabled) }
    }

    public var progressBarThickness: Double {
        get { store.double(forKey: Key.progressBarThickness) ?? 2 }
        set { store.setDouble(newValue, forKey: Key.progressBarThickness) }
    }

    public var progressBarColorHex: String {
        get { store.string(forKey: Key.progressBarColorHex) ?? Self.defaultColorHex }
        set { store.setString(newValue, forKey: Key.progressBarColorHex) }
    }

    public var scrollEnabled: Bool {
        get { store.bool(forKey: Key.scrollEnabled) ?? true }
        set { store.setBool(newValue, forKey: Key.scrollEnabled) }
    }

    public var scrollSpeed: Double {
        get { store.double(forKey: Key.scrollSpeed) ?? 20 }
        set { store.setDouble(newValue, forKey: Key.scrollSpeed) }
    }

    public var useStaticWidth: Bool {
        get { store.bool(forKey: Key.useStaticWidth) ?? false }
        set { store.setBool(newValue, forKey: Key.useStaticWidth) }
    }

    public var staticWidth: Double {
        get { store.double(forKey: Key.staticWidth) ?? 150 }
        set { store.setDouble(newValue, forKey: Key.staticWidth) }
    }

    public var scrollMaxWidth: Double {
        get { store.double(forKey: Key.scrollMaxWidth) ?? 150 }
        set { store.setDouble(newValue, forKey: Key.scrollMaxWidth) }
    }

    public var scrollPauseAtEnds: Double {
        get { store.double(forKey: Key.scrollPauseAtEnds) ?? 1 }
        set { store.setDouble(newValue, forKey: Key.scrollPauseAtEnds) }
    }

    public var textAlignment: MenuBarTextAlignment {
        get { store.string(forKey: Key.textAlignment).flatMap(MenuBarTextAlignment.init) ?? .left }
        set { store.setString(newValue.rawValue, forKey: Key.textAlignment) }
    }

    // Color settings; nil means "use the system color".

    public var appBackgroundColorHex: String? {
        get { store.string(forKey: Key.appBackgroundColorHex) }
        set { store.setString(newValue, forKey: Key.appBackgroundColorHex) }
    }

    public var appTextColorHex: String? {
        get { store.string(forKey: Key.appTextColorHex) }
        set { store.setString(newValue, forKey: Key.appTextColorHex) }
    }

    public var menuBarTextColorHex: String? {
        get { store.string(forKey: Key.menuBarTextColorHex) }
        set { store.setString(newValue, forKey: Key.menuBarTextColorHex) }
    }

    public var progressBarBackgroundColorHex: String? {
        get { store.string(forKey: Key.progressBarBackgroundColorHex) }
        set { store.setString(newValue, forKey: Key.progressBarBackgroundColorHex) }
    }

    public var trackTemplate: String {
        get {
            guard let value = store.string(forKey: Key.trackTemplate),
                  !value.isEmpty,
                  TrackTemplate.validate(value) == nil else {
                return Self.defaultTrackTemplate
            }
            return value
        }
        set { store.setString(newValue, forKey: Key.trackTemplate) }
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
