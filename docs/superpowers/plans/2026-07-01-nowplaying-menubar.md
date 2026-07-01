# NowPlayingBar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu bar app that logs into Spotify via OAuth 2.0 (PKCE) and shows the currently playing track in the status bar.

**Architecture:** Swift Package Manager project. A `NowPlayingCore` library holds all pure/testable logic (models, title formatting, PKCE, HTTP client, auth, loopback server, Keychain). A `NowPlayingBar` executable target wires AppKit (`NSStatusItem`, menu, timer) on top of the library. Tests target `NowPlayingCore` only. No Xcode project file — build/run/test entirely from the `swift` CLI. The Dock icon is suppressed at runtime with `NSApp.setActivationPolicy(.accessory)` (the programmatic equivalent of `LSUIElement`).

**Tech Stack:** Swift 5.9, AppKit, Network.framework (loopback HTTP), CryptoKit (PKCE SHA256), Security.framework (Keychain), XCTest. No third-party dependencies.

## Global Constraints

- Platform floor: `macOS 13`. Swift tools version `5.9`.
- No third-party runtime dependencies. Foundation/AppKit/Network/CryptoKit/Security only.
- No Dock icon: set `NSApp.setActivationPolicy(.accessory)` at launch (do NOT rely on an Info.plist).
- OAuth: Authorization Code + PKCE, **no client secret**. Scope: `user-read-currently-playing`.
- Redirect URI: `http://127.0.0.1:8888/callback` (port `8888`).
- Refresh token stored in macOS Keychain; access token in memory only.
- Client ID supplied at runtime via env var `SPOTIFY_CLIENT_ID`.
- Title format `Artist — Track`, truncate to 30 chars with `…`; idle glyph `♪`; logged-out label `Login`.
- Maintain `CHANGELOG.md` (Keep a Changelog style, newest on top). Phase 1 = `0.1.0`.

---

### Task 1: Project scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/NowPlayingCore/Placeholder.swift`
- Create: `Sources/NowPlayingBar/main.swift`
- Create: `Tests/NowPlayingCoreTests/ScaffoldTests.swift`
- Create: `CHANGELOG.md`

**Interfaces:**
- Consumes: nothing.
- Produces: buildable package with targets `NowPlayingCore` (library), `NowPlayingBar` (executable), `NowPlayingCoreTests`.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NowPlayingBar",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "NowPlayingCore"),
        .executableTarget(
            name: "NowPlayingBar",
            dependencies: ["NowPlayingCore"]
        ),
        .testTarget(
            name: "NowPlayingCoreTests",
            dependencies: ["NowPlayingCore"]
        ),
    ]
)
```

- [ ] **Step 2: Add a placeholder so the library compiles**

`Sources/NowPlayingCore/Placeholder.swift`:
```swift
enum NowPlayingCorePlaceholder {}
```

- [ ] **Step 3: Add a minimal executable entry point**

`Sources/NowPlayingBar/main.swift`:
```swift
import AppKit

// Wiring is fleshed out in Task 8. For scaffold we just prove it links.
_ = NSApplication.shared
print("NowPlayingBar scaffold")
```

- [ ] **Step 4: Add a trivial test to prove the test target runs**

`Tests/NowPlayingCoreTests/ScaffoldTests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class ScaffoldTests: XCTestCase {
    func testScaffold() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 5: Write `CHANGELOG.md`**

```markdown
# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

- Project scaffold: SPM package with core library, executable, and test targets.
```

- [ ] **Step 6: Build and test**

Run: `swift build && swift test`
Expected: build succeeds; `ScaffoldTests.testScaffold` PASSES.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources Tests CHANGELOG.md
git commit -m "feat: scaffold SPM package for NowPlayingBar"
```

---

### Task 2: Models + title formatter

**Files:**
- Create: `Sources/NowPlayingCore/NowPlaying.swift`
- Create: `Sources/NowPlayingCore/TitleFormatter.swift`
- Create: `Tests/NowPlayingCoreTests/TitleFormatterTests.swift`
- Delete: `Sources/NowPlayingCore/Placeholder.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct NowPlaying: Equatable { let artist: String; let track: String; init(artist:track:) }`
  - `enum DisplayState: Equatable { case loggedOut; case idle; case playing(NowPlaying) }`
  - `enum TitleFormatter { static let maxLength = 30; static func title(for: DisplayState) -> String }`

- [ ] **Step 1: Write the failing tests**

`Tests/NowPlayingCoreTests/TitleFormatterTests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class TitleFormatterTests: XCTestCase {
    func testLoggedOut() {
        XCTAssertEqual(TitleFormatter.title(for: .loggedOut), "Login")
    }

    func testIdle() {
        XCTAssertEqual(TitleFormatter.title(for: .idle), "♪")
    }

    func testPlayingShort() {
        let np = NowPlaying(artist: "Radiohead", track: "Idioteque")
        XCTAssertEqual(TitleFormatter.title(for: .playing(np)), "Radiohead — Idioteque")
    }

    func testPlayingTruncatesLongTitle() {
        let np = NowPlaying(artist: "A Very Long Artist Name Here",
                            track: "And An Even Longer Track Title")
        let title = TitleFormatter.title(for: .playing(np))
        XCTAssertEqual(title.count, TitleFormatter.maxLength)
        XCTAssertTrue(title.hasSuffix("…"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TitleFormatterTests`
Expected: FAIL — `NowPlaying` / `TitleFormatter` not found.

- [ ] **Step 3: Write the models**

`Sources/NowPlayingCore/NowPlaying.swift`:
```swift
public struct NowPlaying: Equatable {
    public let artist: String
    public let track: String

    public init(artist: String, track: String) {
        self.artist = artist
        self.track = track
    }
}

public enum DisplayState: Equatable {
    case loggedOut
    case idle
    case playing(NowPlaying)
}
```

- [ ] **Step 4: Write the formatter**

`Sources/NowPlayingCore/TitleFormatter.swift`:
```swift
public enum TitleFormatter {
    public static let maxLength = 30

    public static func title(for state: DisplayState) -> String {
        switch state {
        case .loggedOut:
            return "Login"
        case .idle:
            return "♪"
        case .playing(let np):
            return truncate("\(np.artist) — \(np.track)", to: maxLength)
        }
    }

    static func truncate(_ s: String, to max: Int) -> String {
        guard s.count > max else { return s }
        let end = s.index(s.startIndex, offsetBy: max - 1)
        return String(s[..<end]) + "…"
    }
}
```

- [ ] **Step 5: Remove the placeholder**

```bash
rm Sources/NowPlayingCore/Placeholder.swift
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter TitleFormatterTests`
Expected: all 4 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/NowPlayingCore Tests/NowPlayingCoreTests/TitleFormatterTests.swift
git commit -m "feat: add NowPlaying model and title formatter"
```

---

### Task 3: PKCE generator

**Files:**
- Create: `Sources/NowPlayingCore/PKCE.swift`
- Create: `Tests/NowPlayingCoreTests/PKCETests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct PKCE { let verifier: String; let challenge: String; init() }`
  - `static func makeVerifier(length: Int = 64) -> String`
  - `static func challenge(for verifier: String) -> String`

- [ ] **Step 1: Write the failing tests**

Uses the RFC 7636 Appendix B test vector for the challenge.

`Tests/NowPlayingCoreTests/PKCETests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class PKCETests: XCTestCase {
    func testChallengeMatchesRFC7636Vector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        XCTAssertEqual(PKCE.challenge(for: verifier),
                       "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testVerifierHasRequestedLength() {
        XCTAssertEqual(PKCE.makeVerifier(length: 64).count, 64)
    }

    func testVerifierUsesOnlyUnreservedChars() {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        XCTAssertTrue(PKCE.makeVerifier().allSatisfy { allowed.contains($0) })
    }

    func testInitPopulatesBothFields() {
        let pkce = PKCE()
        XCTAssertFalse(pkce.verifier.isEmpty)
        XCTAssertEqual(pkce.challenge, PKCE.challenge(for: pkce.verifier))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PKCETests`
Expected: FAIL — `PKCE` not found.

- [ ] **Step 3: Write the implementation**

`Sources/NowPlayingCore/PKCE.swift`:
```swift
import Foundation
import CryptoKit

public struct PKCE {
    public let verifier: String
    public let challenge: String

    public init() {
        let verifier = Self.makeVerifier()
        self.verifier = verifier
        self.challenge = Self.challenge(for: verifier)
    }

    public static func makeVerifier(length: Int = 64) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var rng = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars.randomElement(using: &rng)! })
    }

    public static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PKCETests`
Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NowPlayingCore/PKCE.swift Tests/NowPlayingCoreTests/PKCETests.swift
git commit -m "feat: add PKCE verifier/challenge generation"
```

---

### Task 4: HTTP abstraction + Spotify client

**Files:**
- Create: `Sources/NowPlayingCore/HTTPFetching.swift`
- Create: `Sources/NowPlayingCore/SpotifyClient.swift`
- Create: `Tests/NowPlayingCoreTests/MockHTTP.swift`
- Create: `Tests/NowPlayingCoreTests/SpotifyClientTests.swift`

**Interfaces:**
- Consumes: `NowPlaying`.
- Produces:
  - `protocol HTTPFetching { func data(for: URLRequest) async throws -> (Data, URLResponse) }` (URLSession conforms)
  - `enum SpotifyClientError: Error, Equatable { case unauthorized; case unexpectedStatus(Int) }`
  - `struct SpotifyClient { init(http: HTTPFetching, tokenProvider: @escaping () async throws -> String); func currentlyPlaying() async throws -> NowPlaying? }`

- [ ] **Step 1: Write the HTTP abstraction**

`Sources/NowPlayingCore/HTTPFetching.swift`:
```swift
import Foundation

public protocol HTTPFetching {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPFetching {}
```

- [ ] **Step 2: Write the mock used by tests**

`Tests/NowPlayingCoreTests/MockHTTP.swift`:
```swift
import Foundation
@testable import NowPlayingCore

final class MockHTTP: HTTPFetching {
    var status: Int
    var body: Data
    private(set) var lastRequest: URLRequest?

    init(status: Int, body: Data = Data()) {
        self.status = status
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}
```

- [ ] **Step 3: Write the failing client tests**

`Tests/NowPlayingCoreTests/SpotifyClientTests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class SpotifyClientTests: XCTestCase {
    private func client(_ mock: MockHTTP) -> SpotifyClient {
        SpotifyClient(http: mock, tokenProvider: { "test-token" })
    }

    func testParsesPlayingTrack() async throws {
        let json = """
        {"item":{"name":"Idioteque","artists":[{"name":"Radiohead"}]}}
        """
        let np = try await client(MockHTTP(status: 200, body: Data(json.utf8)))
            .currentlyPlaying()
        XCTAssertEqual(np, NowPlaying(artist: "Radiohead", track: "Idioteque"))
    }

    func test204ReturnsNil() async throws {
        let np = try await client(MockHTTP(status: 204)).currentlyPlaying()
        XCTAssertNil(np)
    }

    func test401ThrowsUnauthorized() async {
        do {
            _ = try await client(MockHTTP(status: 401)).currentlyPlaying()
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? SpotifyClientError, .unauthorized)
        }
    }

    func testSendsBearerToken() async throws {
        let mock = MockHTTP(status: 204)
        _ = try await client(mock).currentlyPlaying()
        XCTAssertEqual(mock.lastRequest?.value(forHTTPHeaderField: "Authorization"),
                       "Bearer test-token")
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `swift test --filter SpotifyClientTests`
Expected: FAIL — `SpotifyClient` not found.

- [ ] **Step 5: Write the client**

`Sources/NowPlayingCore/SpotifyClient.swift`:
```swift
import Foundation

public enum SpotifyClientError: Error, Equatable {
    case unauthorized
    case unexpectedStatus(Int)
}

public struct SpotifyClient {
    private let http: HTTPFetching
    private let tokenProvider: () async throws -> String

    public init(http: HTTPFetching, tokenProvider: @escaping () async throws -> String) {
        self.http = http
        self.tokenProvider = tokenProvider
    }

    public func currentlyPlaying() async throws -> NowPlaying? {
        let token = try await tokenProvider()
        var request = URLRequest(
            url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyClientError.unexpectedStatus(-1)
        }
        switch http.statusCode {
        case 204: return nil
        case 401: throw SpotifyClientError.unauthorized
        case 200: return try Self.parse(data)
        default: throw SpotifyClientError.unexpectedStatus(http.statusCode)
        }
    }

    static func parse(_ data: Data) throws -> NowPlaying? {
        struct Artist: Decodable { let name: String }
        struct Item: Decodable { let name: String; let artists: [Artist] }
        struct Payload: Decodable { let item: Item? }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let item = payload.item else { return nil }
        return NowPlaying(artist: item.artists.first?.name ?? "", track: item.name)
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter SpotifyClientTests`
Expected: all 4 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/NowPlayingCore/HTTPFetching.swift Sources/NowPlayingCore/SpotifyClient.swift Tests/NowPlayingCoreTests/MockHTTP.swift Tests/NowPlayingCoreTests/SpotifyClientTests.swift
git commit -m "feat: add Spotify currently-playing client with injectable HTTP"
```

---

### Task 5: Keychain wrapper

**Files:**
- Create: `Sources/NowPlayingCore/Keychain.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct Keychain { init(service: String = "com.nowplayingbar.tokens"); func set(_:for:); func get(_:) -> String?; func delete(_:) }`

Note: Keychain access is unreliable in a headless `swift test` run (no signed host app), so this task is verified manually rather than with an automated test.

- [ ] **Step 1: Write the wrapper**

`Sources/NowPlayingCore/Keychain.swift`:
```swift
import Foundation
import Security

public struct Keychain {
    private let service: String

    public init(service: String = "com.nowplayingbar.tokens") {
        self.service = service
    }

    public func set(_ value: String, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    public func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/NowPlayingCore/Keychain.swift
git commit -m "feat: add Keychain wrapper for refresh token storage"
```

---

### Task 6: Spotify auth (config, token exchange, refresh)

**Files:**
- Create: `Sources/NowPlayingCore/SpotifyConfig.swift`
- Create: `Sources/NowPlayingCore/SpotifyAuth.swift`
- Create: `Tests/NowPlayingCoreTests/TokenResponseTests.swift`

**Interfaces:**
- Consumes: `HTTPFetching`, `Keychain`, `PKCE`, `SpotifyConfig`.
- Produces:
  - `struct SpotifyConfig { init(clientID: String, port: UInt16 = 8888, scope: String = "user-read-currently-playing"); let clientID, redirectURI, scope: String; let port: UInt16 }`
  - `struct TokenResponse: Decodable, Equatable { accessToken: String; refreshToken: String?; expiresIn: Int }`
  - `enum AuthError: Error { case notLoggedIn, tokenRequestFailed }`
  - `actor SpotifyAuth { init(config:http:keychain:); var isLoggedIn: Bool; func authorizeURL(pkce:state:) -> URL; func exchange(code:verifier:) async throws; func validAccessToken() async throws -> String; @discardableResult func refresh() async throws -> String; func logout() }`

- [ ] **Step 1: Write config**

`Sources/NowPlayingCore/SpotifyConfig.swift`:
```swift
import Foundation

public struct SpotifyConfig {
    public let clientID: String
    public let redirectURI: String
    public let scope: String
    public let port: UInt16

    public init(clientID: String,
                port: UInt16 = 8888,
                scope: String = "user-read-currently-playing") {
        self.clientID = clientID
        self.port = port
        self.redirectURI = "http://127.0.0.1:\(port)/callback"
        self.scope = scope
    }
}
```

- [ ] **Step 2: Write the failing token-parse test**

`Tests/NowPlayingCoreTests/TokenResponseTests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class TokenResponseTests: XCTestCase {
    func testDecodesTokenResponse() throws {
        let json = """
        {"access_token":"AT","refresh_token":"RT","expires_in":3600,"token_type":"Bearer"}
        """
        let token = try JSONDecoder().decode(TokenResponse.self, from: Data(json.utf8))
        XCTAssertEqual(token, TokenResponse(accessToken: "AT", refreshToken: "RT", expiresIn: 3600))
    }

    func testRefreshTokenOptional() throws {
        let json = #"{"access_token":"AT2","expires_in":3600}"#
        let token = try JSONDecoder().decode(TokenResponse.self, from: Data(json.utf8))
        XCTAssertNil(token.refreshToken)
        XCTAssertEqual(token.accessToken, "AT2")
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter TokenResponseTests`
Expected: FAIL — `TokenResponse` not found.

- [ ] **Step 4: Write auth**

`Sources/NowPlayingCore/SpotifyAuth.swift`:
```swift
import Foundation

public struct TokenResponse: Decodable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int

    public init(accessToken: String, refreshToken: String?, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

public enum AuthError: Error {
    case notLoggedIn
    case tokenRequestFailed
}

public actor SpotifyAuth {
    private let config: SpotifyConfig
    private let http: HTTPFetching
    private let keychain: Keychain
    private let refreshAccount = "spotify-refresh-token"

    private var accessToken: String?
    private var expiry: Date?

    public init(config: SpotifyConfig,
                http: HTTPFetching = URLSession.shared,
                keychain: Keychain = Keychain()) {
        self.config = config
        self.http = http
        self.keychain = keychain
    }

    public var isLoggedIn: Bool {
        keychain.get(refreshAccount) != nil
    }

    public func authorizeURL(pkce: PKCE, state: String) -> URL {
        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "client_id", value: config.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: config.redirectURI),
            .init(name: "scope", value: config.scope),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: pkce.challenge),
            .init(name: "state", value: state),
        ]
        return comps.url!
    }

    public func exchange(code: String, verifier: String) async throws {
        let token = try await postToken(form([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientID,
            "code_verifier": verifier,
        ]))
        store(token)
    }

    public func validAccessToken() async throws -> String {
        if let token = accessToken, let expiry, expiry > Date().addingTimeInterval(30) {
            return token
        }
        return try await refresh()
    }

    @discardableResult
    public func refresh() async throws -> String {
        guard let refreshToken = keychain.get(refreshAccount) else {
            throw AuthError.notLoggedIn
        }
        let token = try await postToken(form([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientID,
        ]))
        store(token)
        return token.accessToken
    }

    public func logout() {
        keychain.delete(refreshAccount)
        accessToken = nil
        expiry = nil
    }

    private func store(_ token: TokenResponse) {
        accessToken = token.accessToken
        expiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        if let refreshToken = token.refreshToken {
            keychain.set(refreshToken, for: refreshAccount)
        }
    }

    private func postToken(_ body: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)

        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.tokenRequestFailed
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func form(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter TokenResponseTests`
Expected: both tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/NowPlayingCore/SpotifyConfig.swift Sources/NowPlayingCore/SpotifyAuth.swift Tests/NowPlayingCoreTests/TokenResponseTests.swift
git commit -m "feat: add Spotify OAuth PKCE token exchange and refresh"
```

---

### Task 7: Loopback callback server

**Files:**
- Create: `Sources/NowPlayingCore/LoopbackServer.swift`
- Create: `Tests/NowPlayingCoreTests/LoopbackServerTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `final class LoopbackServer { init(port: UInt16); func waitForCode() async throws -> String; func stop(); static func extractCode(from: String) -> String? }`

- [ ] **Step 1: Write the failing test (pure request parsing)**

`Tests/NowPlayingCoreTests/LoopbackServerTests.swift`:
```swift
import XCTest
@testable import NowPlayingCore

final class LoopbackServerTests: XCTestCase {
    func testExtractsCodeFromRequestLine() {
        let request = "GET /callback?code=abc123&state=xyz HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        XCTAssertEqual(LoopbackServer.extractCode(from: request), "abc123")
    }

    func testReturnsNilWhenNoCode() {
        let request = "GET /callback?error=access_denied HTTP/1.1\r\n\r\n"
        XCTAssertNil(LoopbackServer.extractCode(from: request))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LoopbackServerTests`
Expected: FAIL — `LoopbackServer` not found.

- [ ] **Step 3: Write the server**

`Sources/NowPlayingCore/LoopbackServer.swift`:
```swift
import Foundation
import Network

public final class LoopbackServer {
    private let port: UInt16
    private var listener: NWListener?

    public init(port: UInt16) {
        self.port = port
    }

    /// Listens on 127.0.0.1:port and resolves with the `code` from the first
    /// callback request, then shuts down.
    public func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let listener = try NWListener(
                    using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
                self.listener = listener
                var finished = false

                listener.newConnectionHandler = { [weak self] connection in
                    connection.start(queue: .main)
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
                        data, _, _, _ in
                        guard !finished else { return }
                        let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                        let html = "<html><body>Login complete. You can close this window.</body></html>"
                        let response = """
                        HTTP/1.1 200 OK\r
                        Content-Type: text/html\r
                        Content-Length: \(html.utf8.count)\r
                        Connection: close\r
                        \r
                        \(html)
                        """
                        connection.send(content: Data(response.utf8),
                                        completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                        if let code = Self.extractCode(from: request) {
                            finished = true
                            self?.stop()
                            continuation.resume(returning: code)
                        }
                    }
                }
                listener.start(queue: .main)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    static func extractCode(from request: String) -> String? {
        guard let firstLine = request.split(separator: "\r\n").first,
              let pathPart = firstLine.split(separator: " ").dropFirst().first,
              let comps = URLComponents(string: "http://localhost\(pathPart)") else {
            return nil
        }
        return comps.queryItems?.first(where: { $0.name == "code" })?.value
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LoopbackServerTests`
Expected: both tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NowPlayingCore/LoopbackServer.swift Tests/NowPlayingCoreTests/LoopbackServerTests.swift
git commit -m "feat: add loopback HTTP server to capture OAuth callback"
```

---

### Task 8: AppKit wiring + end-to-end integration

**Files:**
- Create: `Sources/NowPlayingBar/MenuBarController.swift`
- Create: `Sources/NowPlayingBar/AppDelegate.swift`
- Modify: `Sources/NowPlayingBar/main.swift` (replace scaffold body)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `SpotifyConfig`, `SpotifyAuth`, `SpotifyClient`, `LoopbackServer`, `PKCE`, `TitleFormatter`, `DisplayState`, `NowPlaying`, `SpotifyClientError`.
- Produces: the runnable app (no further tasks depend on it).

- [ ] **Step 1: Write the menu builder**

`Sources/NowPlayingBar/MenuBarController.swift`:
```swift
import AppKit

final class MenuBarController {
    func buildMenu(isLoggedIn: Bool,
                   nowPlayingTitle: String,
                   target: AnyObject,
                   authAction: Selector,
                   quitAction: Selector) -> NSMenu {
        let menu = NSMenu()

        let info = NSMenuItem(title: nowPlayingTitle, action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)

        menu.addItem(.separator())

        let auth = NSMenuItem(title: isLoggedIn ? "Logout" : "Login",
                              action: authAction, keyEquivalent: "")
        auth.target = target
        menu.addItem(auth)

        let quit = NSMenuItem(title: "Quit", action: quitAction, keyEquivalent: "q")
        quit.target = target
        menu.addItem(quit)

        return menu
    }
}
```

- [ ] **Step 2: Write the app delegate**

`Sources/NowPlayingBar/AppDelegate.swift`:
```swift
import AppKit
import NowPlayingCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menuBuilder = MenuBarController()
    private let config: SpotifyConfig
    private let auth: SpotifyAuth
    private var client: SpotifyClient!
    private var timer: Timer?
    private var state: DisplayState = .loggedOut

    override init() {
        guard let clientID = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_ID"],
              !clientID.isEmpty else {
            fatalError("Set the SPOTIFY_CLIENT_ID environment variable before launching.")
        }
        self.config = SpotifyConfig(clientID: clientID)
        self.auth = SpotifyAuth(config: config)
        super.init()
        self.client = SpotifyClient(http: URLSession.shared) { [auth] in
            try await auth.validAccessToken()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        applyState(.loggedOut)

        Task { await tick() }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { await self?.tick() }
        }
    }

    private func tick() async {
        guard await auth.isLoggedIn else { applyState(.loggedOut); return }
        do {
            if let np = try await client.currentlyPlaying() {
                applyState(.playing(np))
            } else {
                applyState(.idle)
            }
        } catch SpotifyClientError.unauthorized {
            do {
                _ = try await auth.refresh()
            } catch {
                applyState(.loggedOut)
            }
        } catch {
            // Network hiccup: keep the last shown title, retry next tick.
        }
    }

    private func applyState(_ newState: DisplayState) {
        Task { @MainActor in
            self.state = newState
            let loggedIn = await auth.isLoggedIn
            self.statusItem.button?.title = TitleFormatter.title(for: newState)
            self.statusItem.menu = self.menuBuilder.buildMenu(
                isLoggedIn: loggedIn,
                nowPlayingTitle: TitleFormatter.title(for: newState),
                target: self,
                authAction: #selector(self.toggleAuth),
                quitAction: #selector(self.quit))
        }
    }

    @objc private func toggleAuth() {
        Task {
            if await auth.isLoggedIn {
                await auth.logout()
                applyState(.loggedOut)
            } else {
                await login()
            }
        }
    }

    private func login() async {
        let pkce = PKCE()
        let stateParam = PKCE.makeVerifier(length: 16)
        let url = await auth.authorizeURL(pkce: pkce, state: stateParam)
        let server = LoopbackServer(port: config.port)
        NSWorkspace.shared.open(url)
        do {
            let code = try await server.waitForCode()
            try await auth.exchange(code: code, verifier: pkce.verifier)
            await tick()
        } catch {
            server.stop()
            applyState(.loggedOut)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

- [ ] **Step 3: Replace `main.swift` body**

`Sources/NowPlayingBar/main.swift`:
```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 4: Build and run the full test suite**

Run: `swift build && swift test`
Expected: build succeeds; all tests from Tasks 2–7 PASS.

- [ ] **Step 5: Manual end-to-end verification**

Prereqs: create a Spotify app at developer.spotify.com, add redirect URI
`http://127.0.0.1:8888/callback`, copy the Client ID.

Run:
```bash
SPOTIFY_CLIENT_ID=<your-client-id> swift run NowPlayingBar
```
Verify, with Spotify playing on any device:
1. No Dock icon appears; a `Login` item shows in the menu bar.
2. Click it → browser opens Spotify consent → approve → browser shows "Login complete".
3. Within ~5s the menu bar shows `Artist — Track`.
4. Pause playback → within ~5s it shows `♪`.
5. Menu shows the current title (disabled), `Logout`, and `Quit`.
6. `Logout` returns the title to `Login`; `Quit` exits.

- [ ] **Step 6: Update `CHANGELOG.md`**

Replace the `## [Unreleased]` section with:
```markdown
## [0.1.0] - 2026-07-01

### Added
- macOS menu bar app (no Dock icon) showing the currently playing Spotify track.
- Spotify OAuth 2.0 login via Authorization Code + PKCE with a loopback callback server.
- Refresh token stored in the macOS Keychain; silent access-token refresh.
- 5s polling of the currently-playing track; `Artist — Track` display (truncated),
  `♪` when idle, `Login` when logged out.
- Menu with Login/Logout toggle and Quit.
```

- [ ] **Step 7: Commit**

```bash
git add Sources/NowPlayingBar CHANGELOG.md
git commit -m "feat: wire AppKit menu bar app and release 0.1.0"
```
