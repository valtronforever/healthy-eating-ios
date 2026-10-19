# Healthy Eating for iOS

[![CI](https://github.com/valtronforever/healthy-eating-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/valtronforever/healthy-eating-ios/actions/workflows/ci.yml)

The native dashboard for the self-hosted Healthy Eating nutrition tracker. Food is logged through
an AI assistant connected to the backend's MCP server; the app shows trends, provenance and the
connection status.

Status: early scaffold. The app builds with the approved design system and onboarding (server
address and connection steps); sign-in and live data are not built yet, so data screens show
sample data. See [AGENTS.md](AGENTS.md) for the stack, layout, commands and product rules.

- [Design system spec](design/system/README.md): tokens, copy rules, component guidelines.
- [App icon package](design/README.md): the approved R4 Fork + knife conversation icon.

## Build and test

Requirements: Xcode 26 or later (the project was created with Xcode 27.1) and an iOS 18 or later
simulator. No third-party packages.

```bash
open HealthyEating.xcodeproj
xcodebuild -scheme HealthyEating -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme HealthyEating -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Use any installed simulator (`xcrun simctl list devices available`). If `xcodebuild` reports
that it needs Xcode rather than the Command Line Tools, run
`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` or prefix the commands with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Colors, spacing and radii are generated from `design/system/tokens.json`:

```bash
python3 design/tools/generate_design_tokens.py          # regenerate after changing tokens.json
python3 design/tools/generate_design_tokens.py --check  # fails if generated files are stale
```

To try the app against your own server, run the
[backend](https://github.com/valtronforever/healthy-eating-backend) and enter its address on the
Server screen (`http://localhost` is accepted in debug builds only).

Licensed under [MIT](LICENSE).
