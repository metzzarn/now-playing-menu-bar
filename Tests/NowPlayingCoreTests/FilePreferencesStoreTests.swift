import XCTest
@testable import NowPlayingCore

final class FilePreferencesStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("nowplayingbar-test-\(UUID().uuidString)")
            .appendingPathComponent("config.json")
    }

    func testWritesAndReloadsFromFile() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var prefs = Preferences(store: FilePreferencesStore(url: url))
        prefs.clientID = "abc123"
        prefs.refreshInterval = 5
        prefs.progressBarEnabled = true
        prefs.appBackgroundColorHex = "#101010FF"

        // A fresh store reading the same file sees the persisted values.
        let reloaded = Preferences(store: FilePreferencesStore(url: url))
        XCTAssertEqual(reloaded.clientID, "abc123")
        XCTAssertEqual(reloaded.refreshInterval, 5)
        XCTAssertTrue(reloaded.progressBarEnabled)
        XCTAssertEqual(reloaded.appBackgroundColorHex, "#101010FF")
    }

    func testMissingFileYieldsDefaults() {
        let prefs = Preferences(store: FilePreferencesStore(url: tempURL()))
        XCTAssertNil(prefs.clientID)
        XCTAssertEqual(prefs.refreshInterval, PreferenceDefaults.refreshInterval)
        XCTAssertEqual(prefs.trackTemplate, Preferences.defaultTrackTemplate)
    }
}
