# NowPlayingBar — Phase 2 Design

**Date:** 2026-07-01
**Status:** Approved
**Builds on:** Phase 1 (`docs/superpowers/specs/2026-07-01-nowplaying-menubar-design.md`)

## Goal

Turn the menu bar item into an interactive controller:

- **Right-click** → the simple menu (Login/Logout, Preferences…, Quit).
- **Left-click (logged in)** → a rich `NSMenu` whose top item is a custom view showing
  album art, track name, artist, album, a progress bar, current position and total
  length in `M:ss`, and previous / play-pause / next transport buttons.
- A simple **Preferences** window holding the Spotify **Client ID** and the **refresh
  interval**.

## Scopes & API changes

- Add scopes `user-read-playback-state` and `user-modify-playback-state` to the existing
  `user-read-currently-playing`.
- A scope change forces a **one-time re-login**: persist the granted scope string; if the
  configured scope set differs from the persisted one, treat the session as needing
  re-auth (`needsReauth`).
- Replace `GET /v1/me/player/currently-playing` with `GET /v1/me/player`, which returns
  `is_playing`, `progress_ms`, and `item` (with `duration_ms`, `name`, `artists`,
  `album.name`, `album.images`).
- Add controls:
  - `POST /v1/me/player/next`
  - `POST /v1/me/player/previous`
  - `PUT /v1/me/player/play`
  - `PUT /v1/me/player/pause`

## Configuration change: Client ID

Phase 1 read `SPOTIFY_CLIENT_ID` from the environment. Phase 2 stores the Client ID in
`UserDefaults` (entered via Preferences). On launch:

- If no Client ID is stored, the environment variable `SPOTIFY_CLIENT_ID` is used as a
  fallback (keeps `swift run` workflow working). If neither is set, the menu shows a
  disabled "Set Client ID in Preferences…" state and Login is unavailable; the app does
  not crash.

## Components

New and changed units. Core logic stays in `NowPlayingCore` (testable); AppKit views live
in the `NowPlayingBar` executable.

| Unit | Location | Responsibility |
|------|----------|----------------|
| `PlaybackState` | Core (new) | Model: `track`, `artist`, `album`, `artworkURL: URL?`, `isPlaying: Bool`, `progressMs: Int`, `durationMs: Int` |
| `SpotifyClient` | Core (extend) | `playbackState() -> PlaybackState?` via `GET /me/player`; `next()`, `previous()`, `play()`, `pause()` |
| `SpotifyAuth` | Core (extend) | New scopes; persist granted scope; `needsReauth: Bool` |
| `Preferences` | Core (new) | `UserDefaults`-backed: `clientID: String?`, `refreshInterval: TimeInterval` (default 5, allowed 3/5/10) |
| `TimeFormatter` | Core (new) | `string(fromMs:) -> String` producing `M:ss` (pure) |
| `NowPlayingView` | exe (new) | Custom `NSView`: album art, labels, `NSProgressIndicator` (or custom bar), position/length labels, three transport `NSButton`s; delegates actions to `AppDelegate` |
| `ArtworkLoader` | exe (new) | Async album-art fetch with an in-memory cache keyed by URL; returns `NSImage`; placeholder on failure |
| `PreferencesWindowController` | exe (new) | `NSWindowController` with a Client ID `NSTextField` and a refresh-interval control; writes to `Preferences` |
| `MenuBarController` | exe (extend) | Builds both the simple menu and the rich menu (embedding `NowPlayingView`) |
| `AppDelegate` | exe (extend) | Click routing (left vs right), timers (poll + interpolation), wiring, Preferences window |

### Key interfaces

- `PlaybackState` (Core):
  ```swift
  public struct PlaybackState: Equatable {
      public let track: String
      public let artist: String
      public let album: String
      public let artworkURL: URL?
      public let isPlaying: Bool
      public let progressMs: Int
      public let durationMs: Int
  }
  ```
- `SpotifyClient` additions:
  - `func playbackState() async throws -> PlaybackState?` — `nil` on HTTP 204 (no active device).
  - `func next() async throws`, `previous()`, `play()`, `pause()` — issue the verb+path above; treat 2xx as success, 401 as `unauthorized`, other non-2xx as `unexpectedStatus`.
- `TimeFormatter.string(fromMs ms: Int) -> String` — clamps negatives to 0; `M:ss` (e.g. `0:07`, `3:45`, `12:03`).
- `Preferences`:
  - `init(defaults: UserDefaults = .standard)`
  - `var clientID: String?` (get/set)
  - `var refreshInterval: TimeInterval` (get/set; default 5)
- `SpotifyAuth.needsReauth: Bool` — true when persisted granted scope ≠ configured scope.

## Click routing

- Stop setting `statusItem.menu` (that pops on any click and blocks left/right differentiation).
- Configure `statusItem.button` with a target/action and
  `sendAction(on: [.leftMouseUp, .rightMouseUp])`.
- In the action, read `NSApp.currentEvent?.type`:
  - `.rightMouseUp` → simple menu.
  - `.leftMouseUp` → rich menu if logged in and playback available; otherwise simple menu.
- Present via `statusItem.button.performClick`-style `menu.popUp(positioning:at:in:)` anchored
  to the button, then clear so the next click re-evaluates.

## Rich view layout

`NowPlayingView`, ~300×160 pt:

```
┌─────────────────────────────────────┐
│ ┌──────┐  Track Name                 │
│ │ album│  Artist Name                │
│ │  art │  Album Name                 │
│ └──────┘                             │
│  ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░           │
│  1:23                          3:45   │
│          ⏮      ⏯      ⏭              │
└─────────────────────────────────────┘
```

- Album art: 64×64, rounded; placeholder until `ArtworkLoader` resolves.
- Labels truncate with tail ellipsis.
- Progress bar: display-only (no click-to-seek in phase 2).
- Play-pause button icon reflects `isPlaying` (SF Symbols `play.fill` / `pause.fill`;
  `backward.fill` / `forward.fill` for prev/next).
- Buttons live in the custom view, so clicking them does not dismiss the menu.

## Data flow

Two cadences driven by `AppDelegate`:

1. **Poll timer** (interval = `Preferences.refreshInterval`, default 5s): `GET /me/player`
   → update `PlaybackState`; refresh menu-bar title and, if the rich view is on screen,
   its labels/art/progress. Re-sync `progressMs` to the server value.
2. **Interpolation timer** (1s, only while `isPlaying`): advance the local `progressMs` by
   ~1000ms so the bar and position label move smoothly between polls. Reset on each poll.

**Menu-tracking constraint:** while an `NSMenu` is open, the run loop enters
event-tracking mode and default-mode timers do not fire. Both timers are therefore added
to `RunLoop.main` in `.common` run-loop modes so they keep firing while the menu is open.

**Transport actions:** optimistic — on play/pause tap, flip `isPlaying` and the icon
immediately, send the request, then reconcile on the next poll. On next/previous, send the
request and trigger an immediate `GET /me/player` refresh.

## Error handling

| Case | Behavior |
|------|----------|
| `GET /me/player` → 204 (no active device) | Rich view shows "Nothing playing"; transport disabled. |
| Control call → 403/404 (no active device / restriction) | Revert optimistic icon; keep menu open; next poll reconciles. |
| HTTP 401 | Refresh access token once, retry (existing phase-1 behavior extended to new calls). |
| No Client ID configured | Menu shows disabled "Set Client ID in Preferences…"; Login unavailable; no crash. |
| Scope changed (`needsReauth`) | Treat as logged-out until the user re-logs in. |
| Artwork fetch failure | Show placeholder image. |
| Network failure on poll | Keep last state; retry next tick. |

## Testing

Unit tested (pure or injected `HTTPFetching`/`UserDefaults`):

- `TimeFormatter.string(fromMs:)` — `0`, `7000`, `225000`, negative clamps to `0:00`,
  minute rollover (`60000` → `1:00`).
- `SpotifyClient.playbackState` parsing — full 200 body, 204 → nil, body with empty
  `album.images` → `artworkURL == nil`, `is_playing` true/false.
- `SpotifyClient` control methods — mock `HTTPFetching` asserts each issues the correct
  HTTP method and path; 401 → `unauthorized`, other non-2xx → `unexpectedStatus`.
- `SpotifyAuth.needsReauth` — persisted scope equal vs different from configured scope.
- `Preferences` — round-trips `clientID` and `refreshInterval` through an isolated
  `UserDefaults(suiteName:)`; default interval is 5.

Manual verification: left/right click routing; rich view rendering and truncation; live
progress movement while menu open; play-pause / next / previous; Preferences window edits
take effect (Client ID enables login, interval changes poll cadence); re-auth prompt after
scope change.

## Out of scope (Phase 2)

Click-to-seek on the progress bar, volume control, device switching, playlist/queue views,
launch-at-login, global hotkeys, `.app` bundling and code signing (tracked separately).

## Versioning

Release as `0.2.0`; add a `## [0.2.0] - 2026-07-01` entry to `CHANGELOG.md`.
