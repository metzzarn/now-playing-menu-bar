import Foundation

/// Storage for sensitive values (the Spotify refresh token, granted scope).
public protocol SecretStore: AnyObject {
    func get(_ account: String) -> String?
    func set(_ value: String, for account: String)
    func delete(_ account: String)
}

/// Stores secrets as JSON at ~/.config/nowplayingbar/credentials.json, restricted
/// to owner read/write (0600). Plaintext on disk — no macOS Keychain prompts.
public final class FileSecretStore: SecretStore {
    private let url: URL
    private var values: [String: String]

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/nowplayingbar", isDirectory: true)
            .appendingPathComponent("credentials.json")
    }

    public init(url: URL = FileSecretStore.defaultURL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            self.values = dict
        } else {
            self.values = [:]
        }
    }

    public func get(_ account: String) -> String? { values[account] }

    public func set(_ value: String, for account: String) {
        values[account] = value
        persist()
    }

    public func delete(_ account: String) {
        values[account] = nil
        persist()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(values).write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            // Best-effort; a failed write shouldn't crash the app.
        }
    }
}
