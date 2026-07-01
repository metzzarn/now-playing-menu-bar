# NowPlayingBar — Phase 3 Design

**Date:** 2026-07-01
**Status:** Approved
**Builds on:** Phase 2 (`docs/superpowers/specs/2026-07-01-phase2-playback-control-design.md`)

## Goal

Enrich the menu-bar status item itself:

1. An **optional thin progress bar** drawn under the track title in the menu bar.
   Preferences: enable/disable, thickness, and color.
2. **Optional back-and-forth scrolling (marquee)** of the track title when it is
   long. Preferences: enable/disable, scroll speed, max width before scrolling, and
   pause duration at each end.

Both require replacing the plain `statusItem.button.title` with a custom-drawn view.

## Rendering approach

A single custom `StatusItemView: NSView` draws the title as an attributed string
(offset horizontally by a scroll value) and, when enabled, a thin progress line beneath
it. The view is a passive display layer: its `hitTest(_:)` returns `nil` so the
underlying `statusItem.button` continues to receive left/right clicks (preserving phase-2
click routing). The view sets `statusItem.length` to `min(textWidth, maxWidth)` (or the
natural text width when scrolling is off and the text fits).

## Components

| Unit | Location | Responsibility |
|------|----------|----------------|
| `MenuBarStyle` | Core (new) | Value type holding all phase-3 display settings (below) |
| `Marquee` | Core (new, pure) | `offset(elapsed:textWidth:viewWidth:speed:pause:) -> CGFloat` — back-and-forth scroll math |
| `ColorComponents` | Core (new, pure) | Parse `#RRGGBB`/`#RRGGBBAA` → `(r,g,b,a)` doubles; `nil` on malformed input |
| `Preferences` | Core (extend) | New keys + accessors with defaults |
| `StatusItemView` | exe (new) | Draws title (with scroll offset) + optional progress bar; sets `statusItem.length`; owns the marquee timer |
| `NSColor+Hex` | exe (new) | Build `NSColor` from `ColorComponents` (and hex string) |
| `PreferencesWindowController` | exe (extend) | Add a "Menu Bar" settings section |
| `AppDelegate` | exe (extend) | Feed title + progress fraction + `MenuBarStyle` into `StatusItemView`; rebuild style on Preferences save |

### `MenuBarStyle`

```swift
public struct MenuBarStyle: Equatable {
    public let progressBarEnabled: Bool
    public let thickness: CGFloat        // points, 1...4
    public let colorHex: String          // "#RRGGBBAA"
    public let scrollEnabled: Bool
    public let scrollSpeed: CGFloat       // points per second
    public let maxWidth: CGFloat          // points; scroll triggers past this
    public let pauseAtEnds: TimeInterval  // seconds paused at each end
}
```

### Preferences additions (with defaults)

| Key | Type | Default |
|-----|------|---------|
| `progressBarEnabled` | Bool | `false` |
| `progressBarThickness` | Double | `2` |
| `progressBarColorHex` | String | `#1DB954FF` (Spotify green) |
| `scrollEnabled` | Bool | `false` |
| `scrollSpeed` | Double | `40` |
| `scrollMaxWidth` | Double | `180` |
| `scrollPauseAtEnds` | Double | `1.5` |

`Preferences` gains a computed `menuBarStyle: MenuBarStyle` assembled from these keys, plus
individual setters used by the Preferences window.

## `Marquee.offset` semantics

Pure function producing the horizontal pixel offset (≥ 0, meaning "shift text left by N")
for a ping-pong scroll:

- If `textWidth <= viewWidth`: always returns `0` (no scrolling needed).
- Travel distance `d = textWidth - viewWidth`. One leg takes `d / speed` seconds.
- Timeline per cycle: pause at start (`pause`), scroll left over `d/speed`, pause at end
  (`pause`), scroll back right over `d/speed`, repeat.
- Returns the current offset in `0...d` based on `elapsed.truncatingRemainder` over the
  full cycle duration.

## Data flow

- The phase-2 poll and 1 s interpolation timers already track progress. Extend the update
  path so each refresh also calls `statusItemView.update(text:progress:style:)` with the
  current title, `progress = durationMs > 0 ? Double(progressMs)/Double(durationMs) : nil`,
  and the current `MenuBarStyle`.
- `StatusItemView` owns a **marquee timer** (~20 fps, added to `RunLoop.main` in `.common`
  mode) that it starts only when `scrollEnabled` is true and the measured text width exceeds
  `maxWidth`; otherwise it invalidates the timer. The timer advances an internal `elapsed`
  clock and calls `Marquee.offset(...)`, then `needsDisplay = true`.
- Progress bar is drawn only when `progressBarEnabled` and a fractional progress is present
  (a track is loaded). Hidden when idle / logged out.
- When `scrollEnabled` is false, the title truncates to `maxWidth` with a tail ellipsis.

## Preferences window additions

A "Menu Bar" section below the existing fields:

- Progress bar: `NSButton` checkbox (enable); `NSStepper` + label for thickness (1–4);
  `NSColorWell` for color.
- Scrolling: `NSButton` checkbox (enable); numeric `NSTextField`s for speed (pt/s),
  max width (pt), and end pause (s).

Save persists all values and invokes the existing `onSave`, which rebuilds `MenuBarStyle`
and refreshes the status item immediately. The color well value is converted to
`#RRGGBBAA` via `NSColor+Hex` before storing.

## Error handling / edges

| Case | Behavior |
|------|----------|
| Malformed stored color hex | `ColorComponents` returns nil; `StatusItemView` falls back to `labelColor`. |
| Nothing playing / logged out | No progress bar; no scrolling (short text); normal idle/`Login` glyph. |
| `durationMs == 0` | `progress` is nil → no bar drawn even if enabled. |
| Scroll enabled but text fits within `maxWidth` | No marquee timer; static text. |
| Thickness out of 1–4 range (corrupted defaults) | Clamped to 1–4 when building `MenuBarStyle`. |

## Testing

Unit tested (pure, in `NowPlayingCore`):

- `Marquee.offset`: returns 0 when `textWidth <= viewWidth`; 0 during the opening pause;
  half-travel at the expected mid-leg time; `d` at the far end; decreasing during the
  return leg; periodic across a full cycle.
- `ColorComponents`: parses `#RRGGBB` (alpha defaults to 1), `#RRGGBBAA`; returns nil for
  bad length / non-hex; case-insensitive.
- `Preferences`: round-trips each new key; `menuBarStyle` reflects defaults on a fresh
  store and clamps thickness to 1–4.

Manual: toggle bar on/off; change thickness and color live; toggle scrolling with a long
title and watch ping-pong + end pauses; verify clicks still open the correct menus with the
custom view in place.

## Out of scope (Phase 3)

Per-scroll gradients/fades, vertical progress, animation easing curves, marquee for the
rich-menu labels (this phase is the menu-bar status item only), launch-at-login, `.app`
bundling/signing.

## Versioning

Release `0.3.0`; add `## [0.3.0] - 2026-07-01` to `CHANGELOG.md`.
