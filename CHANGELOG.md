# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.4.0] - 2026-07-01

### Added
- Tabbed Preferences window: a "Spotify" tab (Client ID + Refresh) and a
  "Menu Bar" tab (progress bar + scrolling settings).
- Menu-bar width mode toggle: either grow the item up to a max width, or use a
  fixed static width (the inactive field is disabled). Preferences opens on the
  Menu Bar tab by default.
- Menu-bar title alignment setting (left / center / right).
- Click the album art in the left-click menu to bring the Spotify app to the front.

## [0.3.0] - 2026-07-01

### Added
- Optional thin progress bar under the menu-bar track title, with configurable
  enable/disable, thickness (1–4 pt), and color (color picker).
- Optional back-and-forth (marquee) scrolling of long menu-bar titles, with
  configurable enable/disable, speed, max width before scrolling, and end pause.
- Preferences "Menu Bar" section for all of the above.

### Changed
- Menu-bar status item is now custom-drawn (title + optional bar + optional scroll)
  instead of a plain text title; clicks still route to the same left/right menus.

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

## [0.1.0] - 2026-07-01

### Added
- macOS menu bar app (no Dock icon) showing the currently playing Spotify track.
- Spotify OAuth 2.0 login via Authorization Code + PKCE with a loopback callback server.
- Refresh token stored in the macOS Keychain; silent access-token refresh.
- 5s polling of the currently-playing track; `Artist — Track` display (truncated),
  `♪` when idle, `Login` when logged out.
- Menu with Login/Logout toggle and Quit.
