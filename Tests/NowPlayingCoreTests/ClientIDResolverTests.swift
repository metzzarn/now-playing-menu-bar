import XCTest
@testable import NowPlayingCore

final class ClientIDResolverTests: XCTestCase {
    private func prefs(_ id: String?) -> Preferences {
        var p = Preferences(defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)
        p.clientID = id
        return p
    }

    func testPrefersPreferences() {
        XCTAssertEqual(ClientIDResolver.resolve(preferences: prefs("pref"),
            environment: ["SPOTIFY_CLIENT_ID": "env"]), "pref")
    }

    func testFallsBackToEnv() {
        XCTAssertEqual(ClientIDResolver.resolve(preferences: prefs(nil),
            environment: ["SPOTIFY_CLIENT_ID": "env"]), "env")
    }

    func testNilWhenNeither() {
        XCTAssertNil(ClientIDResolver.resolve(preferences: prefs(nil), environment: [:]))
    }

    func testIgnoresEmptyEnv() {
        XCTAssertNil(ClientIDResolver.resolve(preferences: prefs(nil),
            environment: ["SPOTIFY_CLIENT_ID": ""]))
    }
}
