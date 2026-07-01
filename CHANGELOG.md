# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
