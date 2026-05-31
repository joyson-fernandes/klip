# gifsnap — Design Spec

Date: 2026-05-31

## Overview

A lightweight macOS menu bar app that records any region of the screen as an animated GIF with a single hotkey press. No Dock icon, no friction.

---

## Core User Flow

1. User presses **⌘⇧G** (global hotkey)
2. Screen dims — user drags to select a region (live pixel dimensions shown)
3. User presses **↵** — recording starts, a small floating HUD shows elapsed time
4. User presses **⌘⇧G** again — recording stops
5. GIF is saved to the configured folder and raw data copied to the clipboard
6. A macOS notification fires: "GIF saved — also copied to clipboard"

---

## Architecture

Six focused components, all Swift. No third-party Swift dependencies. One bundled binary (`gifski`).

### MenuBarController
- `NSStatusItem` with a custom icon in the menu bar
- Opens the settings popover on click
- Registers the global hotkey via `NSEvent.addGlobalMonitorForEvents`
- Delegates hotkey events to `RegionSelector` or `CaptureEngine` depending on state

### RegionSelector
- Full-screen transparent `NSWindow` covering all displays
- `NSCursor.crosshair` active while the window is shown
- Mouse drag produces a live-updated `CGRect` selection with a purple border and corner handles
- Pixel dimensions badge updates in real time
- ↵ confirms → hands `CGRect` to `CaptureEngine`; Esc cancels

### CaptureEngine
- Uses `ScreenCaptureKit` (`SCStream`) restricted to the selected `CGRect`
- Captures `CMSampleBuffer` frames at the user-configured FPS
- Converts each buffer to a PNG and writes it to a temp directory (`/tmp/gifsnap-<uuid>/frame-NNNN.png`)
- Maintains a frame count; stops on hotkey signal from `MenuBarController`

### GIFEncoder
- Receives the temp directory path and settings (FPS, max-width, loop count)
- Shells out to the bundled `gifski` binary:
  ```
  gifski --fps <fps> --width <maxWidth> --repeat <loops> -o output.gif /tmp/gifsnap-<uuid>/frame-*.png
  ```
- Returns the path to the finished `.gif`
- Cleans up the temp directory on completion

### OutputHandler
- Copies the `.gif` file data to `NSPasteboard` (type `com.compuserve.gif`)
- Moves the `.gif` to the configured save folder (default `~/Screenshots`)
- Fires a `UNUserNotificationCenter` notification with the filename
- Deletes the temp directory

### SettingsStore
- `UserDefaults` wrapper (typed, no stringly-typed keys)
- Properties: `fps: Int` (5–30, default 10), `maxWidth: Int` (400–1600, default 800), `loopCount: Int` (0 = forever, default 0), `saveFolder: URL` (default `~/Screenshots`)
- Persists immediately on change; observed via `@AppStorage` in SwiftUI views

---

## UI

### Menu Bar Popover (SwiftUI)
- App icon + name + hotkey hint
- **Start Capture** button (fallback to hotkey)
- FPS slider (5–30, shows current value)
- Max width slider (400–1600px, shows current value)
- Loop toggle: forever / 1 / 2 / 3 / 5 times
- Save folder row with folder picker button
- Quit + version at the bottom

### Region Selector Overlay
- `NSWindow` with `styleMask: .borderless`, `level: .screenSaver`, `isOpaque: false`, `backgroundColor: .clear`
- Dimmed background (50% black) cut out by the selection rect
- Purple (`#5E5CE6`) border with 8px corner handles
- Dimensions badge above the selection
- Bottom hint: "Drag to select · ↵ Start · Esc to cancel"

### Recording HUD
- Small floating pill window (`NSPanel`) pinned to top-centre of the selected region's display
- Red pulsing dot + elapsed timer (MM:SS)
- "⌘⇧G to stop" hint

---

## Settings Defaults

| Setting | Default | Range |
|---|---|---|
| Frame rate | 10 fps | 5–30 fps |
| Max width | 800 px | 400–1600 px |
| Loop count | 0 (forever) | 0, 1, 2, 3, 5 |
| Save folder | `~/Screenshots` | Any folder |

---

## Bundled Dependency

**gifski** — MIT licensed Rust binary for high-quality GIF encoding.
- Bundled in `gifsnap.app/Contents/MacOS/gifski`
- Current release: latest from https://github.com/ImageOptim/gifski/releases
- Shell invocation via `Process` (no Swift wrapper needed)

---

## Permissions Required

- **Screen Recording** (`NSScreenCaptureUsageDescription`) — required for ScreenCaptureKit
- **Notifications** (`UNUserNotificationCenter.requestAuthorization`) — for completion alert

Both requested at first launch with clear purpose strings.

---

## Out of Scope (v1)

- Video recording (MP4/MOV)
- Static screenshot capture
- Upload to Imgur/S3/cloud
- GIF preview or trim before saving
- Multiple monitor spanning (captures single display region only)
- App Store distribution (direct `.dmg` distribution for v1)
