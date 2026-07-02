import XCTest
@testable import NowPlayingCore

final class FileSecretStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("nowplayingbar-secrets-\(UUID().uuidString)")
            .appendingPathComponent("credentials.json")
    }

    func testRoundTripsAndReloads() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = FileSecretStore(url: url)
        store.set("refresh-abc", for: "spotify-refresh-token")
        XCTAssertEqual(store.get("spotify-refresh-token"), "refresh-abc")

        let reloaded = FileSecretStore(url: url)
        XCTAssertEqual(reloaded.get("spotify-refresh-token"), "refresh-abc")

        reloaded.delete("spotify-refresh-token")
        XCTAssertNil(FileSecretStore(url: url).get("spotify-refresh-token"))
    }

    func testFileIsOwnerOnly() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        FileSecretStore(url: url).set("secret", for: "token")
        let perms = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)
    }
}
