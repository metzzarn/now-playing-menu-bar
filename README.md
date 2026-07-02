# NowPlayingBar

A lightweight macOS **menu bar** app that shows what's currently playing on
Spotify and lets you control playback — without a Dock icon or a window in the
way.

## Screenshots

Left-click for the now-playing view with album art, progress, and transport
controls:

![Now-playing drop-down](screenshots/Menu%20bar%20with%20drop-down.png)

Preferences — the Spotify tab (Client ID + refresh) and the Menu Bar tab
(title format, alignment, progress bar, and scrolling / width options):

![Spotify settings](screenshots/Spotify%20settings.png)
![Menu Bar settings](screenshots/Menu%20bar%20settings.png)

## What it does

- Shows the current track in the menu bar, using a **customizable text format**
  (e.g. `Radiohead - Idioteque (2000)`).
- **Left-click** the menu bar item to open a rich now-playing view: album art,
  track / artist / album, a progress bar with elapsed and total time, and
  **previous / play-pause / next** controls.
- **Right-click** for a simple menu: Login / Logout, Preferences…, Quit.
- Optional **thin progress bar** drawn under the menu-bar title (configurable
  thickness and color).
- Optional **marquee scrolling** for long titles (configurable speed, width, and
  end pause).
- **Click the album art** to bring the Spotify app to the front.
- Logs in with **Spotify OAuth 2.0 (Authorization Code + PKCE)** — no client
  secret. The refresh token is stored in `~/.config/nowplayingbar/credentials.json`
  (owner-only, `0600`).

## Requirements

- macOS 13 or later
- Swift 5.9+ toolchain (Xcode command-line tools)
- A Spotify account and a Spotify **Client ID** (free to create)

## Setup

1. Create an app at the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Add the redirect URI **`http://127.0.0.1:8888/callback`**.
3. Copy the **Client ID**.

## Running

```bash
swift run NowPlayingBar
```

On first launch, open **Preferences…** (right-click the menu bar item) and paste
your Client ID into the **Spotify** tab, then choose **Login**. A browser window
opens for Spotify consent; after approving, the current track appears in the
menu bar within a few seconds.

> You can also provide the Client ID via the `SPOTIFY_CLIENT_ID` environment
> variable — Preferences takes precedence when both are set.

> **Security note:** the refresh token is stored in plaintext in
> `~/.config/nowplayingbar/credentials.json` (locked to owner read/write). This
> avoids macOS Keychain prompts at the cost of not encrypting the token at rest.

## Preferences

**Spotify tab**
- **Client ID** — your Spotify app's client ID.
- **Refresh** — how often to poll Spotify (1 / 3 / 5 / 10 s).

**Menu Bar tab**
- **Format** — the menu-bar title template (see below), with live validation.
- **Text alignment** — left / center / right.
- **Progress bar** — enable, thickness (1–4 pt), and color.
- **Scroll long titles** — enable, speed, and end pause.
- **Width** — grow the item up to a **max width**, or use a fixed **static
  width** (toggle chooses which).

### Title format

The format string supports these variables:

| Variable     | Meaning                                   |
|--------------|-------------------------------------------|
| `<title>`    | Track title                               |
| `<artist>`   | Primary artist                            |
| `<artists>`  | All artists, comma-separated              |
| `<album>`    | Album name                                |
| `<year>`     | Album release year                        |

Characters placed **inside** a token act as optional decoration — they render
only when the variable has a value:

- `<(year)>` → `(2000)` when a year exists, otherwise nothing.
- `(<year>)` → literal parentheses that always show (`()` when the year is
  missing).

Default format: `<artists> - <title> <(year)>`.

Invalid formats (unknown variable, unclosed `<`) show an error and disable Save.

## Architecture

Swift Package Manager project with two targets:

- **`NowPlayingCore`** — pure, unit-tested logic: OAuth/PKCE, Spotify API client,
  playback model, preferences, title template, formatting, secret storage. No AppKit.
- **`NowPlayingBar`** — the AppKit executable: status-item rendering, menus,
  the now-playing view, the Preferences window, and timers.

Run the tests with:

```bash
swift test
```

See [`CHANGELOG.md`](CHANGELOG.md) for the feature history.
