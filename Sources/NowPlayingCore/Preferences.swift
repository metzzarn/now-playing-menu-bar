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
        static let scrollMinWidth = "scrollMinWidth"
        static let scrollMaxWidth = "scrollMaxWidth"
        static let scrollPauseAtEnds = "scrollPauseAtEnds"
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

    public var scrollMinWidth: Double {
        get { (defaults.object(forKey: Key.scrollMinWidth) as? Double) ?? 0 }
        set { defaults.set(newValue, forKey: Key.scrollMinWidth) }
    }

    public var scrollMaxWidth: Double {
        get { (defaults.object(forKey: Key.scrollMaxWidth) as? Double) ?? 150 }
        set { defaults.set(newValue, forKey: Key.scrollMaxWidth) }
    }

    public var scrollPauseAtEnds: Double {
        get { (defaults.object(forKey: Key.scrollPauseAtEnds) as? Double) ?? 1.5 }
        set { defaults.set(newValue, forKey: Key.scrollPauseAtEnds) }
    }

    public var menuBarStyle: MenuBarStyle {
        let maxWidth = max(40, scrollMaxWidth)
        return MenuBarStyle(
            progressBarEnabled: progressBarEnabled,
            thickness: CGFloat(min(4, max(1, progressBarThickness))),
            colorHex: progressBarColorHex,
            scrollEnabled: scrollEnabled,
            scrollSpeed: CGFloat(max(0, scrollSpeed)),
            minWidth: CGFloat(max(0, min(scrollMinWidth, maxWidth))),
            maxWidth: CGFloat(maxWidth),
            pauseAtEnds: max(0, scrollPauseAtEnds))
    }
}
