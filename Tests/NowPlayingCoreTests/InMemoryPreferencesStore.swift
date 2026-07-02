import Foundation
@testable import NowPlayingCore

final class InMemoryPreferencesStore: PreferencesStore {
    private var values: [String: Any] = [:]

    func string(forKey key: String) -> String? { values[key] as? String }
    func double(forKey key: String) -> Double? { values[key] as? Double }
    func bool(forKey key: String) -> Bool? { values[key] as? Bool }
    func setString(_ value: String?, forKey key: String) { values[key] = value }
    func setDouble(_ value: Double, forKey key: String) { values[key] = value }
    func setBool(_ value: Bool, forKey key: String) { values[key] = value }
}
