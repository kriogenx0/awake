# Awake

A native macOS menubar app that prevents your Mac from sleeping, styled after Caffeine and Caffeinated.

## Features

- **Coffee cup icon** in the menu bar — filled when active, outline when inactive
- **Stay Awake** toggle to manually enable/disable sleep prevention
- **Schedule** — automatically active Monday–Friday, 9 am–6 pm by default (configurable)
- **Display** options — dim the screen (custom dark overlay) or turn off the display after inactivity
- **Keyboard dimming** — brightness-down adds extra overlay darkness (up to 90%); brightness-up removes it. Choose **Enable Brightness Key Control…** and grant Awake Accessibility access, then reopen the menu. Brightness-down lowers the backlight to the floor, then adds extra dimming. Brightness-up removes extra dimming first, then raises the backlight, with a separate 6.25% backlight floor on the unlocked built-in display as a fallback. The floor uses dynamically loaded, private DisplayServices APIs and leaves display sleep alone. Set a comfortable hardware brightness before enabling it. Extra dimming survives mouse activity and can be cleared with **Reset Keyboard Dimming** in the menu; it resets when Awake quits.
- **Wake on activity** — choose **Any activity** to clear inactivity dimming and blackout on movement, clicks, scrolling, typing, modifier keys, tablet input, or gestures, including while Awake is focused; **A click** restricts waking to mouse clicks.
- **Night Dim** — dims the screen continuously during a configurable late-night window (e.g. 11 pm–6 am), independent of the Stay Awake schedule or activity
- **Move mouse to stay awake** — nudges the cursor every minute to simulate activity; an optional stronger mode moves it 500 px and taps Shift (which does nothing on its own)
- **Launch at login** — starts automatically on login (enabled by default)

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Install

```sh
make install
```

This builds a release binary, installs it to `/Applications/Awake.app`, and opens the app.

### Other targets

| Command | Description |
|---|---|
| `make dev` | Build debug and open from build dir |
| `make open` | Build release and open from build dir |
| `make close` | Kill the running instance |
| `make clean` | Remove build artifacts |
| `make uninstall` | Remove from /Applications |
| `make reinstall` | Uninstall then install |

## Settings

Open Settings from the menu bar icon → **Settings…**

- **General** — launch at login, move mouse to stay awake
- **Display** — inactivity timeout, action (dim overlay or turn off), and overlay darkness
- **Keyboard dimming** — brightness-down adds extra overlay darkness (up to 90%); brightness-up removes it. Choose **Enable Brightness Key Control…** and grant Awake Accessibility access, then reopen the menu. Brightness-down lowers the backlight to the floor, then adds extra dimming. Brightness-up removes extra dimming first, then raises the backlight, with a separate 6.25% backlight floor on the unlocked built-in display as a fallback. The floor uses dynamically loaded, private DisplayServices APIs and leaves display sleep alone. Set a comfortable hardware brightness before enabling it. Extra dimming survives mouse activity and can be cleared with **Reset Keyboard Dimming** in the menu; it resets when Awake quits.
- **Wake on activity** — choose **Any activity** to clear inactivity dimming and blackout on movement, clicks, scrolling, typing, modifier keys, tablet input, or gestures, including while Awake is focused; **A click** restricts waking to mouse clicks.
- **Night Dim** — enable/disable, the start/end hour of the late-night dim window, and its own overlay darkness
- **Schedule — Days** — which days the schedule is active
- **Schedule — Hours** — start and end hour for the active window
