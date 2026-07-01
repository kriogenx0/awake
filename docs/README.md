# Awake

A native macOS menubar app that prevents your Mac from sleeping, styled after Caffeine and Caffeinated.

## Features

- **Coffee cup icon** in the menu bar — filled when active, outline when inactive
- **Stay Awake** toggle to manually enable/disable sleep prevention
- **Schedule** — automatically active Monday–Friday, 9 am–6 pm by default (configurable)
- **Display** options — dim or turn off the display after a period of inactivity
- **Allow display sleep without lock** — let the screen sleep without triggering the lock screen
- **Move mouse to stay awake** — nudges the cursor every minute to simulate activity
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
- **Display** — allow display sleep without lock, inactivity timeout and action
- **Schedule — Days** — which days the schedule is active
- **Schedule — Hours** — start and end hour for the active window
