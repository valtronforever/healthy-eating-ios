# AGENTS.md: healthy-eating-ios

Guidance for AI coding agents and contributors working in this repository.

## Project overview

Healthy Eating is an open-source (MIT), self-hostable app for tracking nutrition. It has two parts:

- **healthy-eating-backend** (separate repo): a Python service with an MCP server (food logging and nutrient calculation tools used from LLM clients), a REST API and an OAuth 2.1 authorization server with social login (Google, Microsoft, Apple). Data lives in PostgreSQL.
- **healthy-eating-ios** (this repo): a SwiftUI app where users sign in and see their **statistics and progress**: calories, macronutrients, vitamins and minerals over time.

Positioning: the private, honest dashboard for people who log food by talking to their AI assistant. The app is built around weekly trends and data provenance (which values were estimated, how confident), not per-meal precision. Main users already log food in ChatGPT or Claude; the second group is privacy-minded people and self-hosters.

Non-goals (do not build without an owner decision): own food database, barcode scanning, photo recognition, an in-app AI coach or chat, streaks, badges or social features, meal plans and recipes, exercise tracking, GLP-1 medication tracking.

In v1, food is logged through the MCP server from an LLM client. The app is primarily a viewer: it may edit and delete existing meals (edited values are no longer marked as estimated) and, later, re-log a meal that was already logged (copying its values and provenance), but it never creates meals from scratch. Body weight is optional and opt-in: it may be read from Apple Health or entered by hand, and when weight tracking is off no weight appears anywhere in the app. Do not build food recognition or nutrient calculation into the app; the backend owns that logic.

Status: early v1. The Xcode project, the design system (tokens and components) and the app
shell exist; onboarding A1, A2 and A4 work against a user-entered server address. Sign-in
(OAuth), the REST client and Keychain storage are not built yet, and the data screens (Today,
History, Trends) show `SampleData` because the backend has no meal or statistics endpoints.
See the workspace `APP_STATE.md` for what is verified.

`design/` holds the approved app icon package for issue #42 (see `design/README.md`), the
design summary `design/DESIGN.md`, the high-fidelity screens in `design/mockups/` (A1 to G3, PNG
and PDF) and the approved design system spec in `design/system/` (brand book `README.md`,
`tokens.json`, copy rules `content.md`, `app-icon.md`, one README per component). The spec is the source for every color,
type style, spacing value, component and screen in the app; read it before building UI.

## Hard constraints

1. **Open source only.** Prefer Apple frameworks. Any third-party package must be MIT-compatible (MIT, BSD, Apache-2.0) and added via Swift Package Manager. No closed-source SDKs (no Firebase, no Google Sign-In SDK, no analytics/tracking SDKs).
2. **Works with any self-hosted server.** The user enters their server URL. Nothing server-specific (hosts, client secrets, provider keys) is compiled into the app.
3. **Health data is sensitive.** No third-party telemetry. Do not log nutrition data or tokens. Tokens go in the Keychain only.

## Tech stack

| Concern | Choice |
|---|---|
| Language | Swift 6, strict concurrency enabled |
| UI | SwiftUI, Observation (`@Observable`) |
| Charts | Swift Charts |
| Networking | `URLSession` with async/await |
| Auth | `ASWebAuthenticationSession` (OAuth 2.1 Authorization Code + PKCE) |
| Secure storage | Keychain (Security framework) |
| Local cache | SwiftData (optional, for offline viewing) |
| Tests | Swift Testing (unit), XCTest/XCUITest (UI) |
| Min deployment target | iOS 18 (revisit before release) |

Optional: `swift-openapi-generator` (Apache-2.0) to generate the REST client from the backend's `/openapi.json`.

## Layout

```
HealthyEating/
  App/               # @main app, root navigation (TabView), AppModel (server, onboarding state)
  DesignSystem/
    Tokens/          # DesignTokens.generated.swift (colors, Spacing, Radius), Typography.swift
    Components/      # SwiftUI versions of the design system components, each with #Preview blocks
    Preview/         # preview helpers
  Features/
    Onboarding/      # A1 Welcome, A2 Server, A4 Connect your AI assistant (sign-in comes later)
    Dashboard/       # Today, meal detail
    Statistics/      # History, Trends
    Settings/        # server, connection URL, Calm mode, sign out
  Core/
    Auth/            # ServerAddress validation, OAuthRedirect; later discovery, DCR, PKCE, refresh
    API/             # (not yet) REST client, DTOs, error mapping
    Storage/         # (not yet) Keychain, cache
    Models/          # domain models, display formatting, SampleData (until the API exists)
  Resources/         # Assets.xcassets (AppIcon, AppIconImage, Colors/, AccentColor), Localizable.xcstrings
HealthyEatingTests/    # Swift Testing: validation, formatting, token contrast, component renders
HealthyEatingUITests/  # XCUITest: onboarding flow, tabs
design/tools/generate_design_tokens.py   # tokens.json -> color sets + DesignTokens.generated.swift
```

The project uses Xcode folder-synchronized groups: files added under these folders are part of
their target automatically; do not add files to `project.pbxproj` by hand.
`HealthyEating/Info.plist` holds only what build settings cannot express (the `healthyeating`
URL scheme, `OAuthRedirect`); Xcode merges it with the generated Info.plist and the project
excludes it from the folder's resources. Put other Info.plist keys in `INFOPLIST_KEY_*` settings.

## Commands

```bash
open HealthyEating.xcodeproj
xcodebuild -scheme HealthyEating -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme HealthyEating -destination 'platform=iOS Simulator,name=iPhone 17' test
python3 design/tools/generate_design_tokens.py          # after changing design/system/tokens.json
python3 design/tools/generate_design_tokens.py --check  # fails if generated token files are stale
```

Adjust the simulator name to one installed locally (`xcrun simctl list devices`). Before finishing
any change, the project must build without warnings and tests must pass. CI
(`.github/workflows/ci.yml`, on pushes to `main` and on pull requests) runs the token check and
`xcodebuild test` with warnings as errors on the newest Xcode and iPhone simulator of the
`macos-26` runner. `ComponentRenderTests`
writes light, dark and AX5 PNGs of every component to the simulator's temporary directory
(`HealthyEatingRenders`) for visual review; the onboarding UI test keeps named screenshots of A2
(https error) and A4 in the result bundle. Launch arguments (`AppModel.LaunchArgument`):
`-resetOnboarding`, `-skipOnboarding`, `-initialTab today|history|trends|settings`; with
`xcrun simctl ui <device> appearance dark` and `content_size accessibility-extra-extra-extra-large`
they give headless screenshots of every tab in light, dark and AX5. Tests pass on iOS 27 and on
the iOS 18.1 simulator (the deployment target).

## Authentication flow

The app uses the **same OAuth flow as MCP clients**. All social login happens on the backend's web login page, so the app works with any self-hosted server without per-server configuration.

1. User enters the server URL (e.g. `https://food.example.com`). Validate it and require `https` (allow `http://localhost` in debug builds only).
2. Fetch `/.well-known/oauth-authorization-server` to discover endpoints.
3. Register the app via Dynamic Client Registration (`/register`) as a public client with redirect URI `healthyeating://oauth/callback`. Store the resulting `client_id` per server.
4. Start `ASWebAuthenticationSession` to `/authorize` with PKCE (S256), `state`, and the requested scopes. The user picks Google, Microsoft or Apple on the server's login page.
5. Exchange the code at `/token`. Store access and refresh tokens in the Keychain.
6. On `401`, refresh once (single in-flight refresh shared by all requests), then retry. If refresh fails, sign out to onboarding.

Notes:
- First sign-in creates the account on the server if it does not exist yet. A user who connected MCP first signs in here with the same social account and sees their existing data.
- Do not use native provider SDKs. A native "Sign in with Apple" button may be added later via a backend token-exchange endpoint; that requires a backend change first.
- Sign-out revokes tokens at `/revoke` and clears the Keychain.

## Domain and UI rules

- The backend returns nutrients in canonical units (`kcal`, `g`, `mg`, `µg`). Format for display with `Measurement` and the user's locale; never re-compute nutrient values in the app. Energy is shown in the person's `EnergyUnit` (kcal or kJ, a server setting) through `NutritionFormat.energy`; kJ is a display conversion only.
- "Today" and daily charts use the user's local calendar day; send the IANA timezone to the backend where the API asks for it.
- **Neutral feedback is a hard rule.** Never use red, warnings or pop-ups for being over or under a target; show targets as ranges; no streaks, badges or gamification; no "good/bad food", "cheat" or "you went over" wording. Over and under are styled the same way.
- Show data provenance: values the user calculated vs values the assistant estimated, and the confidence.
- Every screen has loading, empty, and error states. The empty state for a new user explains how to connect the MCP server and shows the connection URL with a copy button.
- Support Dynamic Type, Dark Mode and VoiceOver labels on charts.
- All user-facing strings go through the String Catalog (`Localizable.xcstrings`).

## Design system rules

- Colors only through the generated tokens (`Color.ink`, `.foregroundStyle(.inkMuted)`, ...), never
  hex or system colors for content. Every token is an Asset Catalog color set with Any and Dark
  appearances; change `design/system/tokens.json` and rerun the generator, never edit the generated
  files. `AccentColor` mirrors `accent` so system controls pick it up.
- Spacing and corner radii through `Spacing` and `Radius`; corners always `style: .continuous`.
- Text uses Dynamic Type styles (`Typography.swift`), never fixed sizes. Numbers use
  `.metricFont(...)` (SF Pro Rounded, monospaced digits). URLs use `.code`.
- Use the components in `DesignSystem/Components` (ProvenanceBadge, ConfidenceIndicator, RangeBand,
  SummaryCard, MealRow, IntegrationStatus, CalendarDay, KcalBarChart, WeightTrendChart, CopyField,
  Banner, LabeledTextField, Skeleton and `LoadingCards` (loading), StateMessage (server unreachable,
  signed out, nothing yet), `.action(...)` button styles). Host names in titles go through
  `CopyField.breakable` so they wrap at dots, not with hyphens. The design system's PhoneFrame, NavBar,
  TabBar, StatusBar and Keypad are mockup chrome: use the system `TabView` and `NavigationStack`.
- Every component and screen has `#Preview` blocks for light, dark and AX5. At accessibility sizes
  rows stack and nothing truncates.
- Copy follows `design/system/content.md`: sentence case, no exclamation marks, no em dash, fixed
  provenance and confidence words.

## Code conventions

- Views stay small; logic lives in `@Observable` view models or services injected through the environment.
- DTOs (`Codable`, matching the API) are mapped to domain models in `Core/API`. Views never see DTOs.
- No force unwraps outside tests. Errors are typed and mapped to user-facing messages in one place.
- `async`/`await` only; no Combine for new code, no completion-handler APIs.
- Keep the REST client in sync with the backend's `/api/v1`. If the API needs to change, change the backend first.
- Commit messages: imperative mood, short subject line.

## Do not

- Hardcode a server URL, client secret or provider credentials.
- Store tokens in `UserDefaults` or files.
- Add analytics, crash reporting or ad SDKs.
- Add dependencies with non-MIT-compatible licenses.
