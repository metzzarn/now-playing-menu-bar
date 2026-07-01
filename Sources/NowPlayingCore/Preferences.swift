import Foundation

public struct Preferences {
    private let defaults: UserDefaults
    private enum Key {
        static let clientID = "clientID"
        static let refreshInterval = "refreshInterval"
        static let grantedScope = "grantedScope"
    }

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
            return stored == 0 ? 5 : stored
        }
        set { defaults.set(newValue, forKey: Key.refreshInterval) }
    }

    public var grantedScope: String? {
        get { defaults.string(forKey: Key.grantedScope) }
        set { defaults.set(newValue, forKey: Key.grantedScope) }
    }
}
