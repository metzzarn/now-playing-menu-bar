# NowPlayingBar

A lightweight macOS **menu bar** app that shows what's currently playing on
Spotify and lets you control playback — without a Dock icon or a window in the
way.

## Screenshots

Left-click for the now-playing popup — a floating panel with album art, a
seekable progress bar, and transport controls. Choose the **Simple** layout
(art on the left) or **Large Art** (art centered on top):

<img src="screenshots/Now%20Playing%20-%20Simple.png" alt="Now Playing – Simple style" width="420">
<img src="screenshots/Now%20Playing%20-%20Large%20art.png" alt="Now Playing – Large Art style" width="240">

Preferences, split across three tabs:

- **Spotify** — Client ID and refresh interval.
- **Menu Bar** — title format, alignment, progress bar, and scrolling / width options.
- **Style** — theme presets, colors, the Now Playing view style, popup opacity
  and corner radius, and progress-bar settings.

<img src="screenshots/Preferences%20-%20Spotify.png" alt="Spotify tab" width="300">
<img src="screenshots/Preferences%20-%20Menu%20Bar.png" alt="Menu Bar tab" width="300">
<img src="screenshots/Preferences%20-%20Style.png" alt="Style tab" width="300">

## What it does

- Shows the current track in the menu bar, using a **customizable text format**
  (e.g. `Radiohead - Idioteque (2000)`).
- **Left-click** the menu bar item to open a rich now-playing popup: album art,
  track / artist / album, a progress bar with elapsed and total time, and
  **previous / play-pause / next** controls. It's a floating panel that
  dismisses when you click outside it, and stays pinned while Preferences is open.
- Two **Now Playing view styles**: **Simple** (album art on the left) or **Large
  Art** (art centered on top, 50% larger). The popup's **opacity** and **corner
  radius** are adjustable.
- **Right-click** for a simple menu: Login / Logout, Preferences…, Quit.
- Optional **thin progress bar** drawn under the menu-bar title (configurable
  thickness and color).
- Optional **marquee scrolling** for long titles (configurable speed, width, and
  end pause).
- **Click the album art** to bring the Spotify app to the front.
- Logs in with **Spotify OAuth 2.0 (Authorization Code + PKCE)** — no client
  secret. The refresh token is stored in `~/.config/nowplayingbar/credentials.json`
  (owner-only, `0600`).

## Install

**Download a build** — grab `NowPlayingBar.app` from the
[latest release](https://github.com/metzzarn/now-playing-menu-bar/releases/latest),
then drag it into your **Applications** folder.

The app is ad-hoc signed, so macOS Gatekeeper blocks it on first launch. To open
it, **right-click the app → Open** and confirm (only needed once). Alternatively:

```bash
xattr -dr com.apple.quarantine /Applications/NowPlayingBar.app
```

**Or build it yourself** — see [Building](#building) below.

## Requirements

- macOS 13 or later
- A Spotify account and a Spotify **Client ID** (free to create)
- To build from source: a Swift 5.9+ toolchain (Xcode command-line tools)

## Setup

1. Create an app at the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Under the app's APIs, enable **Web API** and **Web Playback SDK**.
3. Add the redirect URI **`http://127.0.0.1:8888/callback`**.
4. Copy the **Client ID**.

## Running

Run directly from source:

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

**Style tab**
- **Theme** — presets (Default, Spotify, Dark, Light, Midnight, Solarized) that
  fill all colors at once; editing any color shows "Custom".
- **Colors** — background, text, and menu-bar text colors.
- **Now Playing view** — the layout style (**Simple** / **Large Art**), popup
  **opacity** (20–100%), and **corner radius** (0–24 pt).
- **Progress bar** — bar thickness, color, and background color.

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

## Building

To build a distributable `NowPlayingBar.app` bundle (release binary + icon,
ad-hoc signed):

```bash
scripts/build-app.sh
```

The bundle is written to `build/NowPlayingBar.app`; drag it into **Applications**
to install. See the [Install](#install) section for the Gatekeeper first-launch step.

See [`CHANGELOG.md`](CHANGELOG.md) for the feature history.
