import Foundation

/// Typed key/value backing for `Preferences`. `double` returns nil when a key is
/// unset so callers can apply their own default.
public protocol PreferencesStore: AnyObject {
    func string(forKey key: String) -> String?
    func double(forKey key: String) -> Double?
    func bool(forKey key: String) -> Bool?
    func setString(_ value: String?, forKey key: String)
    func setDouble(_ value: Double, forKey key: String)
    func setBool(_ value: Bool, forKey key: String)
}

/// A JSON scalar; keeps the on-disk file flat and human-readable.
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        throw DecodingError.dataCorruptedError(
            in: container, debugDescription: "Unsupported preferences value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }
}

/// Persists preferences as pretty JSON at ~/.config/nowplayingbar/config.json.
public final class FilePreferencesStore: PreferencesStore {
    private let url: URL
    private var values: [String: JSONValue]

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/nowplayingbar", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    public init(url: URL = FilePreferencesStore.defaultURL) {
        self.url = url
        self.values = Self.load(url)
    }

    private static func load(_ url: URL) -> [String: JSONValue] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(values).write(to: url, options: .atomic)
        } catch {
            // Best-effort; a failed write shouldn't crash the app.
        }
    }

    public func string(forKey key: String) -> String? {
        if case .string(let value) = values[key] { return value }
        return nil
    }

    public func double(forKey key: String) -> Double? {
        if case .number(let value) = values[key] { return value }
        return nil
    }

    public func bool(forKey key: String) -> Bool? {
        if case .bool(let value) = values[key] { return value }
        return nil
    }

    public func setString(_ value: String?, forKey key: String) {
        values[key] = value.map(JSONValue.string)
        persist()
    }

    public func setDouble(_ value: Double, forKey key: String) {
        values[key] = .number(value)
        persist()
    }

    public func setBool(_ value: Bool, forKey key: String) {
        values[key] = .bool(value)
        persist()
    }
}
