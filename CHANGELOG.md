# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-07-01

### Added
- macOS menu bar app (no Dock icon) showing the currently playing Spotify track.
- Spotify OAuth 2.0 login via Authorization Code + PKCE with a loopback callback server.
- Refresh token stored in the macOS Keychain; silent access-token refresh.
- 5s polling of the currently-playing track; `Artist — Track` display (truncated),
  `♪` when idle, `Login` when logged out.
- Menu with Login/Logout toggle and Quit.
