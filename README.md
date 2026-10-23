# Healthy Eating for iOS

[![CI](https://github.com/valtronforever/healthy-eating-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/valtronforever/healthy-eating-ios/actions/workflows/ci.yml)

The native dashboard for the self-hosted Healthy Eating nutrition tracker. Food is logged through
an AI assistant connected to the backend's MCP server; the app shows trends, provenance and the
connection status.

Status: v1 (MVP) screens done. You sign in to your own server (OAuth in the system web sheet,
tokens in the Keychain), and Today, meal detail and edit, History, Trends and Settings show and
change the data on that server. See [AGENTS.md](AGENTS.md) for the stack, layout, commands and
product rules.

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

## Install on your iPhone

Signing uses your own Apple account; no team ID is stored in the project. With a free Personal
Team (Xcode → Settings → Accounts), the app runs for 7 days, then install it again; a paid
Apple Developer account removes that limit and allows TestFlight.

1. Connect the iPhone by cable, unlock it and tap Trust. Turn on Developer Mode (Settings →
   Privacy & Security → Developer Mode; it appears after the iPhone was connected to Xcode once).
2. Find your team ID (Xcode → Settings → Accounts, or the `OU` in
   `security find-identity -v -p codesigning`) and the iPhone's identifier
   (`xcrun devicectl list devices`), then build and install:

   ```bash
   xcodebuild -scheme HealthyEating -configuration Release \
     -destination 'platform=iOS,id=<iphone-identifier>' -derivedDataPath build \
     DEVELOPMENT_TEAM=<team-id> -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
   xcrun devicectl device install app --device <iphone-identifier> build/Build/Products/Release-iphoneos/HealthyEating.app
   ```

3. The first time, trust the developer on the iPhone: Settings → General → VPN & Device
   Management → your "Apple Development" certificate → Trust.

Release builds accept only `https` server addresses.

To try the app against your own server, run the
[backend](https://github.com/valtronforever/healthy-eating-backend) and enter its address on the
Server screen (`http://localhost` is accepted in debug builds only).

Licensed under [MIT](LICENSE).
