# AGENTS.md — Awake

Awake is a SwiftUI menu-bar app that keeps the Mac awake on a schedule, with display dimming and keyboard brightness control. Features are described in [docs/README.md](docs/README.md). Requires macOS 13+ and full Xcode (the `@State` macro plugin isn't in the Command Line Tools).

## Commands

- `make dev`: quit, clean, and build a dev bundle in `build/`, then open it.
- `make test`: `swift test` against the `Awake` library target (`AwakeTests/`).
- `make build`: Release bundle. `make open`: Release bundle, then open it.
- `make install` / `make uninstall` / `make reinstall`: manage `/Applications/Awake.app`.
- `make close`: quit the app. `make clean`: remove `build/`.

## Layout

- `Awake/AwakeApp.swift`: app entry point (excluded from the SwiftPM library so tests can import the rest).
- `Awake/AppState.swift`: schedule, sleep assertions, and dimming state.
- `Awake/AppMenu.swift`, `Awake/SettingsView.swift`: menu-bar UI and settings.
- `Awake/DimOverlay.swift`: the dimming overlay windows.
- `AwakeTests/`: XCTest suite.
- `scripts/make_icon.swift`: generates `AppIcon.icns`.

## Conventions

- The Makefile compiles an explicit file list with `swiftc`. A new Swift file in `Awake/` must be added to `SOURCES` in the `Makefile` and to `Awake.xcodeproj`. `Package.swift` picks it up automatically for tests.
- The version comes from `MARKETING_VERSION` in `Awake.xcodeproj/project.pbxproj`.
- Keyboard dimming uses private DisplayServices APIs loaded at runtime; keep those calls guarded so a missing symbol never crashes the app.

## Design principles

Follow the [design principles](docs/rules/design-principles.md) for any UI work.

## After changing code

1. `make test`
2. `make dev`

Commit messages are one short, imperative line, like the existing history.
