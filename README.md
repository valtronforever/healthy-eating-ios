# Healthy Eating for iOS

[![CI](https://github.com/valtronforever/healthy-eating-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/valtronforever/healthy-eating-ios/actions/workflows/ci.yml)

The native dashboard for the self-hosted Healthy Eating nutrition tracker. Food is logged through
an AI assistant connected to the backend's MCP server; the app shows trends, provenance and the
connection status.

Status: early, in daily use on the owner's iPhone. You sign in to your own server (OAuth in the
system web sheet, tokens in the Keychain); everything the app shows and changes lives on that
server. What it does:

- **Today, History, Trends:** daily totals against your target ranges, meals with provenance
  (your numbers or estimated, with confidence), meal edit and delete, complete and partial days,
  7, 30 and 90 day trends, fiber, sugar and sodium when meals have them, and a weekly review.
- **Vitamins, minerals and lab results:** vitamins and minerals from the food items your assistant
  lists, with goals or reference ranges and weeks of insights; lab results your assistant saves
  from a report, shown over time next to the intake of the related nutrient, as printed and never
  judged.
- **Weight and energy (opt-in):** weigh-ins from the chat, the app or Apple Health, a smoothed
  trend and an estimate of how many calories you maintain at, from your own log.
- **Apple Health (opt-in):** meals and weigh-ins go to Apple Health; weigh-ins from scales and the
  Health app come back.
- **Widgets:** today's totals on the Home Screen and Lock Screen, updated by the widget itself.
- **Works offline:** the last data stays readable when your server can't be reached.
- **Calm mode:** hides calories everywhere, including the widgets.
- **Settings:** connected assistants with a connection guide, time zone, kcal or kJ, targets, a
  notice when meals stop arriving, data export and account deletion.

See [AGENTS.md](AGENTS.md) for the stack, layout, commands and product rules.

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
