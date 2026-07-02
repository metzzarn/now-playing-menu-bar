# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.12.0] - 2026-07-02

### Added
- Light theme preset (re-added).

### Changed
- Preferences window floats on top; its appearance matches the chosen background
  so controls stay visible on light themes.
- The seek-bar knob darkens on a light background so it stays visible.

## [0.11.0] - 2026-07-02

### Added
- Seek by clicking or dragging the progress bar in the now-playing view. The bar
  scrubs live while dragging and seeks Spotify on release.

## [0.10.0] - 2026-07-02

### Changed
- The Spotify refresh token and granted scope are now stored in
  `~/.config/nowplayingbar/credentials.json` (owner-only, 0600) instead of the
  macOS Keychain — no more Keychain password prompts. The token is plaintext on disk.

## [0.9.0] - 2026-07-02

### Changed
- Progress bar and title scrolling are now enabled by default.
- Only one Preferences window can be open at a time (reopening fronts the existing one).
- Removed the "Light" theme preset.

## [0.8.0] - 2026-07-02

### Changed
- Preferences are now stored in `~/.config/nowplayingbar/config.json` (human-readable
  JSON) instead of macOS UserDefaults. The Spotify refresh token remains in the Keychain.

## [0.7.0] - 2026-07-02

### Added
- Theme presets on the Style tab: Default, Spotify, Dark, Light, Midnight, Solarized.
  Picking one fills all the Style colors; editing a color shows "Custom". Default
  restores the original system colors.

## [0.6.0] - 2026-07-02

### Added
- Style tab in Preferences: background color, text color (applied to the
  Preferences window and the now-playing view), and menu-bar title text color.
- Progress-bar background (track) color setting, under Bar color.
- Color settings default to system colors (adaptive light/dark) until customized.

## [0.5.0] - 2026-07-01

### Added
- Custom menu-bar title format: a validated template using <title>, <artist>,
  <artists> (all artists), <album>, and <year>. Optional decoration characters
  inside a token (e.g. <(year)>) render only when the value is present. Invalid
  formats show an error and block Save.

### Changed
- Playback now captures all artists and the album release year.

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
