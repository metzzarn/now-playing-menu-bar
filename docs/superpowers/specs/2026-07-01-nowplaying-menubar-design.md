# NowPlayingBar — Phase 1 Design

**Date:** 2026-07-01
**Status:** Approved

## Goal

macOS menu bar app showing the currently playing Spotify track. Phase 1 scope:
OAuth 2.0 login, fetch current song, display it in the menu bar. Nothing more.

## Stack

- Native Swift + AppKit.
- `LSUIElement = true` (menu bar only, no Dock icon).
- Single `NSStatusItem`.
- No third-party runtime dependencies. `URLSession` for HTTP, Keychain for secrets.
- Xcode project. Deployment target: macOS 13+.

## Components

Four small, independently testable units.

| Unit | Responsibility | Depends on |
|------|----------------|-----------|
| `AppDelegate` | Owns `NSStatusItem` and menu, drives the refresh timer, holds app state | all others |
| `SpotifyAuth` | PKCE flow, loopback callback server, token exchange + refresh, Keychain storage | Keychain, `URLSession` |
| `SpotifyClient` | Calls `GET /v1/me/player/currently-playing`, parses response | valid access token from `SpotifyAuth` |
| `MenuBarController` | Formats the status title, builds the dropdown menu | — (pure) |

### Interfaces

- `SpotifyAuth`
  - `login()` — starts PKCE flow, opens browser, resolves when tokens stored.
  - `logout()` — clears Keychain + in-memory token.
  - `validAccessToken() async throws -> String` — returns current token, refreshing if expired.
  - `isLoggedIn: Bool`
- `SpotifyClient`
  - `currentlyPlaying() async throws -> NowPlaying?` — `nil` when nothing is playing (HTTP 204).
  - `NowPlaying { artist: String, track: String }`
- `MenuBarController`
  - `title(for state: DisplayState) -> String`
  - `buildMenu(isLoggedIn: Bool) -> NSMenu`

## OAuth Flow (Authorization Code + PKCE)

Public client, **no client secret**.

1. User picks **Login** from the menu.
2. Generate a random code verifier + SHA256 code challenge.
3. Start a loopback HTTP server on `127.0.0.1:8888`, path `/callback`.
4. Open the system browser to the Spotify authorize URL:
   - scope: `user-read-currently-playing`
   - `redirect_uri = http://127.0.0.1:8888/callback`
   - `code_challenge_method = S256`
5. Spotify redirects back to the loopback server with `code`.
6. Exchange `code` (+ verifier) at `POST /api/token` for access + refresh tokens.
7. Store **refresh token in macOS Keychain**. Keep the access token in memory with its expiry.
8. Shut down the loopback server.

Token refresh: when the access token is expired (tracked expiry) or a call returns
`401`, exchange the refresh token for a new access token silently.

## Data Flow

```
Timer (5s) ──▶ SpotifyClient.currentlyPlaying()
                     │
        ┌────────────┼─────────────────────────┐
        ▼            ▼                           ▼
   NowPlaying     nil (204)                   error
        │            │                           │
   "Artist —     idle glyph "♪"          401 → refresh once, retry
   Track" (≤30,                          other → keep last title
   … ellipsis)
```

Not logged in → title shows **"Login"**.

## Menu

- Now-playing text (disabled row, reflects current title)
- ─── separator ───
- **Login** / **Logout** (single row, label toggles by auth state)
- **Quit**

## Error Handling

| Case | Behavior |
|------|----------|
| HTTP 401 | Refresh access token once, retry the call. If refresh fails → logged-out state. |
| HTTP 204 (nothing playing) | Show idle glyph `♪`. |
| Network failure | Keep last shown title, retry on next 5s tick. |
| Refresh token invalid | Clear Keychain, drop to logged-out ("Login"). |

## Display Rules

- Format: `Artist — Track`.
- Truncate to ~30 chars, append `…`.
- Idle (nothing playing): `♪`.
- Logged out: `Login`.

## Testing

- `MenuBarController.title(for:)` — pure function, unit tested (truncation, idle, logged-out).
- `SpotifyClient` response parsing — inject a mock `URLSession`/`URLProtocol`, test 200/204/401.
- Auth loopback flow — manual test (browser interaction).
- XCTest target covering the formatter and client parsing.

## Versioning

Maintain a `CHANGELOG.md` at the repo root. Each released/working version gets an
entry describing changes since the previous version. Format: [Keep a Changelog] style,
semantic version headings (e.g. `## [0.1.0] - 2026-07-01`), newest on top. Phase 1
ships as `0.1.0`.

## One-Time Prerequisite (user)

Create a Spotify app at developer.spotify.com:
- Add redirect URI `http://127.0.0.1:8888/callback`.
- Copy the **Client ID** into the app config.

## Out of Scope (Phase 1)

Playback controls, album art, multiple providers, notifications, preferences window.
