# NowPlayingBar Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add left-click rich menu (album art, metadata, progress bar, transport controls), right-click simple menu, and a Preferences window (Client ID + refresh interval) to NowPlayingBar.

**Architecture:** Extend `NowPlayingCore` with playback model, playback + control API, scope-aware auth, preferences, and a time formatter (all unit-tested). Add AppKit views to the `NowPlayingBar` executable: a custom `NowPlayingView` embedded as an `NSMenuItem.view`, an `ArtworkLoader`, a `PreferencesWindowController`, and click-routing + dual timers in `AppDelegate`.

**Tech Stack:** Swift 5.9, AppKit, Foundation, CryptoKit, Security, XCTest. No third-party deps.

## Global Constraints

- Platform floor `macOS 13`, Swift tools `5.9`. No third-party runtime dependencies.
- Scopes: `user-read-currently-playing user-read-playback-state user-modify-playback-state`.
- Playback read via `GET /v1/me/player`; controls via `POST /v1/me/player/next`, `POST /v1/me/player/previous`, `PUT /v1/me/player/play`, `PUT /v1/me/player/pause`.
- Client ID from `UserDefaults` (Preferences), falling back to env `SPOTIFY_CLIENT_ID`; never crash when absent.
- Refresh interval default 5s, allowed values 3/5/10.
- Time display format `M:ss`; negatives clamp to `0:00`.
- Timers added to `RunLoop.main` in `.common` modes (fire while menu open).
- Release `0.2.0`; add `## [0.2.0] - 2026-07-01` to `CHANGELOG.md`.
- `AppDelegate` remains `@MainActor`; keep tick serialization and login reentrancy guards from phase 1.

---

### Task 1: PlaybackState model + TimeFormatter

**Files:**
- Create: `Sources/NowPlayingCore/PlaybackState.swift`
- Create: `Sources/NowPlayingCore/TimeFormatter.swift`
- Create: `Tests/NowPlayingCoreTests/TimeFormatterTests.swift`

**Interfaces produced:**
- `struct PlaybackState: Equatable { track, artist, album: String; artworkURL: URL?; isPlaying: Bool; progressMs, durationMs: Int }`
- `enum TimeFormatter { static func string(fromMs: Int) -> String }`

- [ ] **Step 1: Failing tests** — `TimeFormatterTests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class TimeFormatterTests: XCTestCase {
    func testZero() { XCTAssertEqual(TimeFormatter.string(fromMs: 0), "0:00") }
    func testSevenSeconds() { XCTAssertEqual(TimeFormatter.string(fromMs: 7000), "0:07") }
    func testMinuteRollover() { XCTAssertEqual(TimeFormatter.string(fromMs: 60000), "1:00") }
    func testMinutesAndSeconds() { XCTAssertEqual(TimeFormatter.string(fromMs: 225000), "3:45") }
    func testNegativeClampsToZero() { XCTAssertEqual(TimeFormatter.string(fromMs: -5000), "0:00") }
    func testTwoDigitMinutes() { XCTAssertEqual(TimeFormatter.string(fromMs: 723000), "12:03") }
}
```
- [ ] **Step 2:** `swift test --filter TimeFormatterTests` → FAIL (not found).
- [ ] **Step 3:** `PlaybackState.swift`:
```swift
import Foundation

public struct PlaybackState: Equatable {
    public let track: String
    public let artist: String
    public let album: String
    public let artworkURL: URL?
    public let isPlaying: Bool
    public let progressMs: Int
    public let durationMs: Int

    public init(track: String, artist: String, album: String, artworkURL: URL?,
                isPlaying: Bool, progressMs: Int, durationMs: Int) {
        self.track = track; self.artist = artist; self.album = album
        self.artworkURL = artworkURL; self.isPlaying = isPlaying
        self.progressMs = progressMs; self.durationMs = durationMs
    }
}
```
`TimeFormatter.swift`:
```swift
public enum TimeFormatter {
    public static func string(fromMs ms: Int) -> String {
        let totalSeconds = max(0, ms) / 1000
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}
```
- [ ] **Step 4:** `swift test --filter TimeFormatterTests` → 6 PASS.
- [ ] **Step 5:** Commit `feat: add PlaybackState model and TimeFormatter`.

---

### Task 2: Preferences

**Files:**
- Create: `Sources/NowPlayingCore/Preferences.swift`
- Create: `Tests/NowPlayingCoreTests/PreferencesTests.swift`

**Interfaces produced:**
- `struct Preferences { init(defaults: UserDefaults = .standard); var clientID: String?; var refreshInterval: TimeInterval }`

- [ ] **Step 1: Failing tests** — `PreferencesTests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class PreferencesTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "test.nowplayingbar.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    func testDefaultInterval() {
        XCTAssertEqual(Preferences(defaults: makeDefaults()).refreshInterval, 5)
    }

    func testClientIDRoundTrips() {
        var prefs = Preferences(defaults: makeDefaults())
        XCTAssertNil(prefs.clientID)
        prefs.clientID = "abc123"
        XCTAssertEqual(prefs.clientID, "abc123")
    }

    func testIntervalRoundTrips() {
        var prefs = Preferences(defaults: makeDefaults())
        prefs.refreshInterval = 10
        XCTAssertEqual(prefs.refreshInterval, 10)
    }
}
```
- [ ] **Step 2:** `swift test --filter PreferencesTests` → FAIL.
- [ ] **Step 3:** `Preferences.swift`:
```swift
import Foundation

public struct Preferences {
    private let defaults: UserDefaults
    private enum Key {
        static let clientID = "clientID"
        static let refreshInterval = "refreshInterval"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var clientID: String? {
        get { defaults.string(forKey: Key.clientID)?.isEmpty == false
                ? defaults.string(forKey: Key.clientID) : nil }
        set { defaults.set(newValue, forKey: Key.clientID) }
    }

    public var refreshInterval: TimeInterval {
        get {
            let stored = defaults.double(forKey: Key.refreshInterval)
            return stored == 0 ? 5 : stored
        }
        set { defaults.set(newValue, forKey: Key.refreshInterval) }
    }
}
```
- [ ] **Step 4:** `swift test --filter PreferencesTests` → 3 PASS.
- [ ] **Step 5:** Commit `feat: add Preferences (UserDefaults) for client ID and refresh interval`.

---

### Task 3: SpotifyClient playback state + controls

**Files:**
- Modify: `Sources/NowPlayingCore/SpotifyClient.swift`
- Create: `Tests/NowPlayingCoreTests/PlaybackStateClientTests.swift`

**Interfaces produced:**
- `func playbackState() async throws -> PlaybackState?`
- `func next() async throws`, `previous()`, `play()`, `pause()`
- Reuses `SpotifyClientError` (`.unauthorized`, `.unexpectedStatus(Int)`).

**Consumes:** `HTTPFetching`, `PlaybackState`, `MockHTTP` (extend to capture method + record path).

- [ ] **Step 1:** Extend `MockHTTP` (test helper) to expose `lastRequest` method/URL — it already records `lastRequest`; add nothing if `httpMethod` + `url` are inspectable (they are).
- [ ] **Step 2: Failing tests** — `PlaybackStateClientTests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class PlaybackStateClientTests: XCTestCase {
    private func client(_ mock: MockHTTP) -> SpotifyClient {
        SpotifyClient(http: mock, tokenProvider: { "t" })
    }

    func testParsesPlaybackState() async throws {
        let json = """
        {"is_playing":true,"progress_ms":12000,
         "item":{"name":"Idioteque","duration_ms":312000,
           "artists":[{"name":"Radiohead"}],
           "album":{"name":"Kid A","images":[{"url":"https://img/1"}]}}}
        """
        let state = try await client(MockHTTP(status: 200, body: Data(json.utf8))).playbackState()
        XCTAssertEqual(state, PlaybackState(track: "Idioteque", artist: "Radiohead",
            album: "Kid A", artworkURL: URL(string: "https://img/1"),
            isPlaying: true, progressMs: 12000, durationMs: 312000))
    }

    func test204ReturnsNil() async throws {
        XCTAssertNil(try await client(MockHTTP(status: 204)).playbackState())
    }

    func testMissingArtworkYieldsNilURL() async throws {
        let json = """
        {"is_playing":false,"progress_ms":0,
         "item":{"name":"X","duration_ms":1000,"artists":[{"name":"Y"}],
           "album":{"name":"Z","images":[]}}}
        """
        let state = try await client(MockHTTP(status: 200, body: Data(json.utf8))).playbackState()
        XCTAssertNil(state?.artworkURL)
    }

    func testNextIssuesPost() async throws {
        let mock = MockHTTP(status: 204)
        try await client(mock).next()
        XCTAssertEqual(mock.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mock.lastRequest?.url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/next")
    }

    func testPlayIssuesPut() async throws {
        let mock = MockHTTP(status: 204)
        try await client(mock).play()
        XCTAssertEqual(mock.lastRequest?.httpMethod, "PUT")
        XCTAssertEqual(mock.lastRequest?.url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/play")
    }

    func testControl401Throws() async {
        do { try await client(MockHTTP(status: 401)).pause(); XCTFail() }
        catch { XCTAssertEqual(error as? SpotifyClientError, .unauthorized) }
    }
}
```
- [ ] **Step 3:** `swift test --filter PlaybackStateClientTests` → FAIL.
- [ ] **Step 4:** Add to `SpotifyClient.swift`:
```swift
public func playbackState() async throws -> PlaybackState? {
    let token = try await tokenProvider()
    var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await http.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw SpotifyClientError.unexpectedStatus(-1)
    }
    switch http.statusCode {
    case 204: return nil
    case 401: throw SpotifyClientError.unauthorized
    case 200: return try Self.parseState(data)
    default: throw SpotifyClientError.unexpectedStatus(http.statusCode)
    }
}

public func next() async throws { try await control(method: "POST", path: "next") }
public func previous() async throws { try await control(method: "POST", path: "previous") }
public func play() async throws { try await control(method: "PUT", path: "play") }
public func pause() async throws { try await control(method: "PUT", path: "pause") }

private func control(method: String, path: String) async throws {
    let token = try await tokenProvider()
    var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/\(path)")!)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (_, response) = try await http.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw SpotifyClientError.unexpectedStatus(-1)
    }
    switch http.statusCode {
    case 200...299: return
    case 401: throw SpotifyClientError.unauthorized
    default: throw SpotifyClientError.unexpectedStatus(http.statusCode)
    }
}

static func parseState(_ data: Data) throws -> PlaybackState? {
    struct Image: Decodable { let url: String }
    struct Album: Decodable { let name: String; let images: [Image] }
    struct Artist: Decodable { let name: String }
    struct Item: Decodable {
        let name: String; let durationMs: Int
        let artists: [Artist]; let album: Album
        enum CodingKeys: String, CodingKey {
            case name, artists, album
            case durationMs = "duration_ms"
        }
    }
    struct Payload: Decodable {
        let isPlaying: Bool; let progressMs: Int?; let item: Item?
        enum CodingKeys: String, CodingKey {
            case item
            case isPlaying = "is_playing"
            case progressMs = "progress_ms"
        }
    }
    let payload = try JSONDecoder().decode(Payload.self, from: data)
    guard let item = payload.item else { return nil }
    return PlaybackState(
        track: item.name,
        artist: item.artists.first?.name ?? "",
        album: item.album.name,
        artworkURL: item.album.images.first.flatMap { URL(string: $0.url) },
        isPlaying: payload.isPlaying,
        progressMs: payload.progressMs ?? 0,
        durationMs: item.durationMs)
}
```
- [ ] **Step 5:** `swift test --filter PlaybackStateClientTests` → PASS.
- [ ] **Step 6:** Commit `feat: add playback state fetch and transport controls to SpotifyClient`.

---

### Task 4: Scope-aware re-auth check

Granted scope is not a secret, so it lives in `Preferences` (UserDefaults), and the
re-auth decision is a pure function — both unit-testable without touching the Keychain.

**Files:**
- Modify: `Sources/NowPlayingCore/Preferences.swift`
- Create: `Sources/NowPlayingCore/ScopeCheck.swift`
- Create: `Tests/NowPlayingCoreTests/ScopeCheckTests.swift`

**Interfaces produced:**
- `Preferences.grantedScope: String?` (get/set).
- `enum ScopeCheck { static func needsReauth(granted: String?, required: String) -> Bool }` — true when `granted != required` (including nil).

**Consumes:** `Preferences`.

- [ ] **Step 1: Failing tests** — `ScopeCheckTests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class ScopeCheckTests: XCTestCase {
    func testNeedsReauthWhenNil() {
        XCTAssertTrue(ScopeCheck.needsReauth(granted: nil, required: "a b"))
    }

    func testNoReauthWhenEqual() {
        XCTAssertFalse(ScopeCheck.needsReauth(granted: "a b", required: "a b"))
    }

    func testNeedsReauthWhenDiffers() {
        XCTAssertTrue(ScopeCheck.needsReauth(granted: "a", required: "a b"))
    }

    func testGrantedScopeRoundTrips() {
        var prefs = Preferences(defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)
        XCTAssertNil(prefs.grantedScope)
        prefs.grantedScope = "a b"
        XCTAssertEqual(prefs.grantedScope, "a b")
    }
}
```
- [ ] **Step 2:** `swift test --filter ScopeCheckTests` → FAIL.
- [ ] **Step 3:** Add to `Preferences.swift` (new key + accessor):
```swift
// in Key enum:
static let grantedScope = "grantedScope"

public var grantedScope: String? {
    get { defaults.string(forKey: Key.grantedScope) }
    set { defaults.set(newValue, forKey: Key.grantedScope) }
}
```
`ScopeCheck.swift`:
```swift
public enum ScopeCheck {
    public static func needsReauth(granted: String?, required: String) -> Bool {
        granted != required
    }
}
```
- [ ] **Step 4:** `swift test --filter ScopeCheckTests` → PASS.
- [ ] **Step 5:** Commit `feat: add granted-scope preference and pure re-auth check`.

**AppDelegate usage (implemented in Task 9):** after a successful `exchange`, set
`preferences.grantedScope = config.scope`; on logout set it to `nil`; treat the session as
logged-out for display whenever `ScopeCheck.needsReauth(granted: preferences.grantedScope,
required: config.scope)` is true.

---

### Task 5: Config scope + Client-ID resolution

**Files:**
- Modify: `Sources/NowPlayingCore/SpotifyConfig.swift`
- Create: `Sources/NowPlayingCore/ClientIDResolver.swift`
- Create: `Tests/NowPlayingCoreTests/ClientIDResolverTests.swift`

**Interfaces produced:**
- `SpotifyConfig` default `scope` becomes the three-scope string.
- `enum ClientIDResolver { static func resolve(preferences: Preferences, environment: [String: String]) -> String? }` — prefers `preferences.clientID`, else `environment["SPOTIFY_CLIENT_ID"]` (non-empty), else nil.

- [ ] **Step 1:** Change `SpotifyConfig.init` default scope to
  `"user-read-currently-playing user-read-playback-state user-modify-playback-state"`.
- [ ] **Step 2: Failing tests** — `ClientIDResolverTests.swift`:
```swift
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
```
- [ ] **Step 3:** `swift test --filter ClientIDResolverTests` → FAIL.
- [ ] **Step 4:** `ClientIDResolver.swift`:
```swift
import Foundation

public enum ClientIDResolver {
    public static func resolve(preferences: Preferences,
                               environment: [String: String]) -> String? {
        if let id = preferences.clientID, !id.isEmpty { return id }
        if let env = environment["SPOTIFY_CLIENT_ID"], !env.isEmpty { return env }
        return nil
    }
}
```
- [ ] **Step 5:** `swift test` (full suite) → all pass, including phase-1 tests.
- [ ] **Step 6:** Commit `feat: broaden scope and add client ID resolver (prefs over env)`.

---

### Task 6: ArtworkLoader

**Files:**
- Create: `Sources/NowPlayingBar/ArtworkLoader.swift`

**Interfaces produced:**
- `actor ArtworkLoader { func image(for url: URL) async -> NSImage? }` with an in-memory `[URL: NSImage]` cache. Returns nil on failure (caller shows placeholder).

- [ ] **Step 1:** Write `ArtworkLoader.swift`:
```swift
import AppKit

actor ArtworkLoader {
    private var cache: [URL: NSImage] = [:]

    func image(for url: URL) async -> NSImage? {
        if let cached = cache[url] { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else { return nil }
        cache[url] = image
        return image
    }
}
```
- [ ] **Step 2:** `swift build` → succeeds.
- [ ] **Step 3:** Commit `feat: add ArtworkLoader with in-memory cache`.

---

### Task 7: NowPlayingView (custom NSView)

**Files:**
- Create: `Sources/NowPlayingBar/NowPlayingView.swift`

**Interfaces produced:**
- `protocol NowPlayingViewDelegate: AnyObject { func didTapPrevious(); func didTapPlayPause(); func didTapNext() }`
- `final class NowPlayingView: NSView { weak var delegate; func update(state: PlaybackState, artwork: NSImage?); func showNothingPlaying() }`
- Fixed frame 300×160. Subviews: `NSImageView` (64×64), three `NSTextField` labels (track/artist/album, tail truncation), an `NSProgressIndicator` (bar style, `minValue 0`, `maxValue = durationMs`), position + length `NSTextField`s, three `NSButton`s with SF Symbols (`backward.fill`, `play.fill`/`pause.fill`, `forward.fill`) targeting delegate methods.

- [ ] **Step 1:** Implement the view with Auto Layout: labels use `lineBreakMode = .byTruncatingTail`; progress uses `TimeFormatter.string(fromMs:)` for the two time labels; `update` sets `doubleValue`/`maxValue` on the indicator and toggles the play/pause symbol via `isPlaying`; `showNothingPlaying` blanks labels to "Nothing playing" and disables the three buttons. Buttons call `delegate?.didTap…()`.
- [ ] **Step 2:** `swift build` → succeeds.
- [ ] **Step 3:** Commit `feat: add NowPlayingView rich menu content view`.

---

### Task 8: PreferencesWindowController

**Files:**
- Create: `Sources/NowPlayingBar/PreferencesWindowController.swift`

**Interfaces produced:**
- `final class PreferencesWindowController: NSWindowController { init(preferences: Preferences, onSave: @escaping (Preferences) -> Void); func show() }`
- A titled, non-resizable `NSWindow` (~360×160) with: a Client ID `NSTextField`, a refresh-interval `NSPopUpButton` (3s/5s/10s), and a Save button that writes both to `Preferences` and invokes `onSave` (so `AppDelegate` can re-resolve the client ID and restart polling). `show()` centers and orders front, activating the app.

- [ ] **Step 1:** Implement the window controller building the window programmatically (no nib); pre-fill fields from the passed `Preferences`; Save persists and calls `onSave`.
- [ ] **Step 2:** `swift build` → succeeds.
- [ ] **Step 3:** Commit `feat: add Preferences window (client ID + refresh interval)`.

---

### Task 9: MenuBarController + AppDelegate wiring, timers, click routing

**Files:**
- Modify: `Sources/NowPlayingBar/MenuBarController.swift`
- Modify: `Sources/NowPlayingBar/AppDelegate.swift`
- Modify: `CHANGELOG.md`

**Consumes:** everything above.

- [ ] **Step 1:** `MenuBarController` gains:
  - `func simpleMenu(isLoggedIn: Bool, hasClientID: Bool, target:, loginAction:, prefsAction:, quitAction:) -> NSMenu` — items: Login/Logout (or disabled "Set Client ID in Preferences…" when `!hasClientID`), Preferences…, Quit.
  - `func richMenu(contentView: NowPlayingView, target:, prefsAction:, quitAction:) -> NSMenu` — first item's `.view = contentView`, then separator, Preferences…, Quit.
- [ ] **Step 2:** `AppDelegate` changes:
  - Replace env-only client ID with `ClientIDResolver.resolve(preferences:environment:)`; store `Preferences`. No `fatalError`.
  - Build `SpotifyConfig` only when a client ID exists; recreate `auth`/`client` when the client ID changes via Preferences save.
  - Track `playback: PlaybackState?` and a persistent `NowPlayingView` instance.
  - **Click routing:** don't assign `statusItem.menu`. Set `statusItem.button` target/action, `sendAction(on: [.leftMouseUp, .rightMouseUp])`. In the handler, read `NSApp.currentEvent?.type`; right → simple menu; left → rich menu if logged in and `playback != nil`, else simple. Present with `menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)`.
  - **Poll timer:** interval `preferences.refreshInterval`; calls `tick()` → `client.playbackState()`; updates title (reuse `TitleFormatter` from `playback.artist/track` or idle), updates the `NowPlayingView`, resolves artwork via `ArtworkLoader`. Add to `RunLoop.main.add(timer, forMode: .common)`.
  - **Interpolation timer:** 1s; while `playback?.isPlaying == true`, increment a local `progressMs` and refresh only the view's progress; add in `.common` mode.
  - **Transport (delegate):** optimistic play/pause (flip icon + local isPlaying, call `client.play()/pause()`, reconcile next poll); next/previous call `client.next()/previous()` then immediate `tick()`. On control error revert.
  - **401 handling:** wrap playback/control calls to refresh-then-retry (extend phase-1 pattern).
  - **Preferences action:** lazily create and `show()` a `PreferencesWindowController`, passing an `onSave` that re-resolves client ID, rebuilds auth/client if changed, and restarts the poll timer with the new interval.
  - **needsReauth:** treat as logged-out (show Login) until re-login.
- [ ] **Step 3:** `swift build && swift test` → build ok, all unit tests pass.
- [ ] **Step 4: Manual verification** (`swift run NowPlayingBar`, Client ID set via Preferences):
  1. Right-click → simple menu (Login/Logout, Preferences…, Quit).
  2. First run with new scopes → Login required; after login, left-click → rich menu.
  3. Rich menu shows art, track/artist/album, progress bar advancing every second, `M:ss` position/length.
  4. Play/pause toggles icon and playback; next/previous change track and view refreshes.
  5. Preferences: entering a Client ID enables Login; changing interval changes poll cadence.
  6. Nothing playing → "Nothing playing", transport disabled.
- [ ] **Step 5:** Update `CHANGELOG.md` with:
```markdown
## [0.2.0] - 2026-07-01

### Added
- Left-click rich menu: album art, track/artist/album, progress bar with M:ss
  position and length, and previous/play-pause/next transport controls.
- Right-click simple menu (Login/Logout, Preferences, Quit).
- Preferences window: Spotify Client ID (persisted, replacing the env var) and
  refresh interval (3/5/10s).
- Broader Spotify scopes (playback-state read + modify); one-time re-login on upgrade.

### Changed
- Playback data now comes from GET /me/player (adds progress and play state).
- Client ID is read from Preferences, falling back to SPOTIFY_CLIENT_ID.
```
- [ ] **Step 6:** Commit `feat: rich/simple menus, transport, preferences wiring; release 0.2.0`.
