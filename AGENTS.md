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
shell exist. Onboarding signs in to a user-entered server with OAuth (A1, A2, the A3 web sheet,
A4); tokens are in the Keychain. The REST client (`Core/API`) covers every `/api/v1` operation;
the data screens (Today, History, Trends) are being moved from `SampleData` to it.
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
| Local cache | `ResponseCache`: the last answer of each GET request as files (offline viewing) |
| Tests | Swift Testing (unit), XCTest/XCUITest (UI) |
| Min deployment target | iOS 18 (revisit before release) |

Optional: `swift-openapi-generator` (Apache-2.0) to generate the REST client from the backend's `/openapi.json`.

## Layout

```
HealthyEating/
  App/               # @main app, root navigation (TabView), AppModel (server, onboarding state)
  DesignSystem/
    Tokens/          # Typography.swift (the generated tokens are in Shared/)
    Components/      # SwiftUI versions of the design system components, each with #Preview blocks
    Preview/         # preview helpers
  Features/
    Onboarding/      # A1 Welcome, A2 Server (Continue signs in: A3 web sheet), A4 Connect your AI assistant
    Dashboard/       # Today, meal detail, usual meals (log one again)
    Statistics/      # History, Trends, Weekly review (D2, opened from Trends)
    Settings/        # server, connection URL, Calm mode, weight tracking, sign out; Linked accounts (link, unlink);
                     # Connected assistants with the connection guide (the A4 steps, to read again)
    Weight/          # D3 Weight and energy (opened from Trends), weigh-ins list and form
  Core/
    Auth/            # ServerAddress, OAuthRedirect, PKCE, OAuthClient (discovery, DCR, token, revoke),
                     # WebAuthenticator (ASWebAuthenticationSession), OAuthSignIn, AuthSession (tokens, refresh),
                     # LoginLinking (add another login to the account)
    API/             # APIClient (+Endpoints: one method per /api/v1 operation), DTOs, APIError (all copy)
    Storage/         # Keychain (SecureStore), MemoryStore for tests, CredentialStore (per server), ResponseCache
    Notices/         # ArrivalNotice: opt-in local notification when meals stop arriving (background app refresh)
    Health/          # AppleHealthStore (HealthKit: body mass and nutrition, system and placeholder), AppleHealthSync
    Models/          # domain models, display formatting, SampleData (until the API exists)
  Resources/         # Assets.xcassets (AppIcon, AppIconImage, AccentColor), Localizable.xcstrings
Shared/              # compiled into the app and the widget extension: DesignTokens.generated.swift and
                     # DesignTokens.xcassets (colors, Spacing, Radius), EnergyUnit, APIDate, TodaySnapshot,
                     # WidgetAccess (the widget's token and its fetch)
HealthyEatingWidgets/  # WidgetKit extension: F1 "Today" widget (small, medium, Lock Screen circular and
                       # rectangular); Info.plist and entitlements excluded from the synced folder
HealthyEatingTests/    # Swift Testing: validation, formatting, token contrast, component renders, auth, API
  Fixtures/openapi.json  # copy of the backend's /api/v1 contract; APIContractTests check the DTOs against it
HealthyEatingUITests/  # XCUITest: onboarding flow, tabs
design/tools/generate_design_tokens.py   # tokens.json -> Shared/ color sets + DesignTokens.generated.swift, app AccentColor
```

The project uses Xcode folder-synchronized groups: files added under these folders are part of
their target automatically; do not add files to `project.pbxproj` by hand.
`HealthyEating/Info.plist` holds only what build settings cannot express (the `healthyeating`
URL scheme, `OAuthRedirect`; `UIBackgroundModes` `fetch` and `BGTaskSchedulerPermittedIdentifiers`
for background refresh; `SharedKeychainGroup` for the widgets); Xcode merges it with the generated Info.plist and the project
excludes it from the folder's resources. Put other Info.plist keys in `INFOPLIST_KEY_*` settings
(`NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` are). `HealthyEating/HealthyEating.entitlements` (HealthKit)
is excluded the same way and set with `CODE_SIGN_ENTITLEMENTS`.

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
(`.github/workflows/ci.yml`, on pushes to `main` and on pull requests, except when only `README.md`
changed) runs the token check and
`xcodebuild test` with warnings as errors on the newest Xcode and iPhone simulator of the
`macos-26` runner; a failed test is retried once (`-retry-tests-on-failure -test-iterations 2`),
because on the CI simulator a UI tap is sometimes lost. (Splitting it into a unit job and three
UI shards was tried on 2026-10-25 and saved about 2 minutes at best, within the runner's
variance, so it was reverted.) In UI tests,
scroll with `app.scrollTo(element)` (`HealthyEatingUITests/ScrollHelpers.swift`) before tapping
anything that may need scrolling: one snapshot per check (every separate
`exists`/`isHittable`/`frame` query costs seconds on CI), and after a swipe it waits until the
element stops moving, since a tap on a gliding list only stops it. `ComponentRenderTests`
writes light, dark and AX5 PNGs of every component to the simulator's temporary directory
(`HealthyEatingRenders`) for visual review; the onboarding UI test keeps named screenshots of A2
(https error) and A4 in the result bundle. Launch arguments (`AppModel.LaunchArgument`):
`-resetOnboarding`, `-skipOnboarding` (signed in with placeholder credentials, no network),
`-placeholderSignIn` (sign-in succeeds without the web sheet), `-initialTab today|history|trends|settings`,
`-showOffline` (with placeholders: the G1 offline banner);
both placeholder arguments keep tokens in memory, never in the Keychain; with
`xcrun simctl ui <device> appearance dark` and `content_size accessibility-extra-extra-extra-large`
they give headless screenshots of every tab in light, dark and AX5. Tests pass on iOS 27 and on
the iOS 18.1 simulator (the deployment target).

End-to-end sign-in against a real backend (run it with `DEV_LOGIN_ENABLED=true`; skipped
otherwise):

```bash
TEST_RUNNER_HE_E2E_SERVER=http://localhost:8000 xcodebuild test -scheme HealthyEating \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:HealthyEatingUITests/SignInEndToEndUITests
```

The second test there checks the "assistant first" path: save a meal for an account through the
backend's MCP `log_meal` first (dev login, any email), then also set
`TEST_RUNNER_HE_E2E_EMAIL=<that email>` and `TEST_RUNNER_HE_E2E_MEAL=<its dish name>`; signing in
must skip onboarding and show the meal on Today. `-resetOnboarding` also clears the Keychain.

## Authentication flow

The app uses the **same OAuth flow as MCP clients**. All social login happens on the backend's web login page, so the app works with any self-hosted server without per-server configuration.

1. User enters the server URL (e.g. `https://food.example.com`). Validate it and require `https` (allow `http://localhost` in debug builds only).
2. Fetch `/.well-known/oauth-authorization-server` to discover endpoints.
3. Register the app via Dynamic Client Registration (`/register`) as a public client with redirect URI `healthyeating://oauth/callback`. Store the resulting `client_id` per server.
4. Start `ASWebAuthenticationSession` to `/authorize` with PKCE (S256), `state`, and the requested scopes. The user picks Google, Microsoft or Apple on the server's login page.
5. Exchange the code at `/token`. Store access and refresh tokens in the Keychain.
6. On `401`, refresh once (single in-flight refresh shared by all requests), then retry. If refresh fails, sign out to onboarding.

Implemented in `Core/Auth`: `OAuthSignIn` runs steps 2 to 5 (the `client_id` is kept per server
across sign-outs; `scope=nutrition`, `resource={server}/mcp`); `AuthSession` hands out tokens and
does step 6's single in-flight refresh (`refresh(rejected:)`); a refused refresh deletes the
tokens and `AppModel.sessionEnded()` returns to Welcome with an explanation.

Notes:
- First sign-in creates the account on the server if it does not exist yet. A user who connected MCP first signs in here with the same social account and sees their existing data.
- Do not use native provider SDKs. A native "Sign in with Apple" button may be added later via a backend token-exchange endpoint; that requires a backend change first.
- Sign-out revokes tokens at `/revoke` and clears the Keychain.

## Domain and UI rules

- The backend returns nutrients in canonical units (`kcal`, `g`, `mg`, `µg`). Format for display with `Measurement` and the user's locale; never re-compute nutrient values in the app. Energy is shown in the person's `EnergyUnit` (kcal or kJ, a server setting) through `NutritionFormat.energy`; kJ is a display conversion only.
- "Today" and daily charts use the user's local calendar day; send the IANA timezone to the backend where the API asks for it.
- **Neutral feedback is a hard rule.** Never use red, warnings or pop-ups for being over or under a target; show targets as ranges; no streaks, badges or gamification; no "good/bad food", "cheat" or "you went over" wording. Over and under are styled the same way.
- Show data provenance: values the user calculated vs values the assistant estimated, and the confidence.
  Meals imported from earlier tracking (backend #27, `Meal.importedFrom`) say "Imported from
  ChatGPT project" on meal detail; the source note is hidden when it only repeats that source.
- Calm mode (Settings, stored on the server and adopted from it with `AppModel.adopt(_:)` whenever
  settings load, never echoed back) hides calories everywhere: Today's hero number (G3 shows
  "Logged N of the last 7 days." instead, a plain count, never a streak), meal rows, meal detail
  and the edit sheet, History days, Trends, the weekly review, the target summary and the calorie
  target in Settings. New screens and widgets must follow it.
- Fiber, sugar and sodium (`OptionalNutrient`, never targets) are optional per meal and only shown
  when present: meal detail rows (± when estimated), one line under the day summary (Today and
  History days) and a Trends card. A value only some meals or days have says so ("2 of 3 meals",
  "on 9 of 18 counted days"). Servers without them decode as none. The edit sheet does not change
  them yet; `APIClient.MealEdit.optional` can.
- Vitamins and minerals (backend #25, `Core/Models/Micronutrients.swift`, 18 nutrients with the
  API's codes; the unit is the code's suffix, `NutrientUnit.micrograms` for µg): the server computes
  them from USDA FoodData Central for the food items the assistant listed; the app only shows them,
  as plain amounts (`NutritionFormat.micronutrient`: two decimals below 1, one below 10), never
  colors or judgments. Meal detail has "Vitamins" and "Minerals" sections and "Food items" (each
  item's grams and the USDA food used, or "Not found in USDA data, no values"). Today and a past
  day show a "Vitamins and minerals" row (`MicronutrientsLink`) when the day has values, opening
  `MicronutrientsView` with "2 of 3 meals" when only some meals have a value; Trends shows the same
  row with averages over the counted days on which every meal has a value ("on 4 of 7 counted
  days"), and so does the weekly review (`MicronutrientsView.averageValues`). Calm mode does not hide them. Servers without them decode as none. An optional reference
  group (Settings, "Vitamin and mineral references": Off, Adult women, Adult men; a server setting)
  adds the server's reference values (`UserSettings.micronutrientReferences`) to day and Trends
  values as a compact `RangeBand` captioned "Reference 8–45 mg" or "Reference at least 320 mg"
  (`NutritionFormat.reference`), never "target" and never judged; meal detail has no bands (a
  daily reference does not fit one meal).
- The weekly review (`Features/Statistics/WeeklyReviewView.swift`) shows `GET /api/v1/weekly-review`
  as facts: its footnote names the days the averages use and why others are left out; Calm mode
  hides calories (weekdays and weekend then compare protein). Week titles use the locale's order
  with an en dash and no spaces ("Oct 12–18", "12–18 Oct").
- The notice when meals stop arriving (`Core/Notices/ArrivalNotice.swift`, Settings) is off by
  default. A background app refresh (`.backgroundTask(.appRefresh)`, about every 6 h when iOS
  allows) posts one local notification when the server's `arrival_status` is `quiet` and the last
  meal arrived 2 days ago or more, once per quiet spell; signing out turns it off. No push service.
  Its wording is about the assistant connection, never about the person's eating or logging.
  The Today footnote's dot follows `arrival_status` (24 h rule while it is `unknown`).
- Weight (`Features/Weight`, `/api/v1/weights`) is opt-in: `UserSettings.weightTracking` comes
  from the server (off until the first weigh-in from the chat or the app, or the Settings toggle).
  While it is off no weight appears anywhere except the Settings toggle and "Delete all weight
  data". Values arrive in kg; `WeightUnit` (kg or lb, a server setting) is display and input only.
  The form accepts "," or "." and 20 to 400 kg. Weight values are plain numbers: no arrows,
  colors, praise or warnings for a change. D3 (`WeightView`) shows the intro with "Turn on"
  while tracking is off; on, the smoothed trend over the last 28 days with weigh-ins faded and
  the energy estimate ("you maintain at about X per day", confidence, what it is based on, or
  what it still needs). Calm mode hides the energy estimate.
- Apple Health sync (ios#31, ios#32, `Core/Health/AppleHealthSync.swift`, `AppModel.setAppleHealthSync`
  / `syncAppleHealth`) is off by default and per device; its switch ("Sync with Apple Health") is
  in Settings (always) and on D3. Meals go one way, the server to Apple Health: the meals of the
  last 365 days are written as one food correlation each (`HKMetadataKeyFoodType` = dish name)
  with energy, protein, fat, carbohydrates, and fiber, sugar and sodium when the meal has them;
  sync identifiers `healthy-eating-meal:<meal id>` (correlation) and `...:<nutrient>` (samples),
  version = the meal's `updated_at` in ms, so a correction replaces it (a value it no longer has
  is deleted) and a server deletion deletes it. Meals sync whether or not weight tracking is on,
  and only when writing dietary energy is allowed. Body mass syncs both ways. In the foreground
  the app asks once more for types a newer version added (`requestAccessIfNeeded`). It runs when the
  switch is turned on, whenever the app becomes active, on D3's refresh and in background refresh
  (shared with the arrival notice); the server cannot reach Apple Health, so a weigh-in logged in
  the chat reaches Apple Health only then. Apple Health to the server: new samples from other
  sources (anchored query, whole history on the first read) go as `apple_health` with their UUID
  as `external_id`; their deletions go to `/api/v1/weights/apple-health-deletions`; deleting one
  of the app's own samples deletes that weigh-in. The server to Apple Health: weigh-ins from the
  chat and the app of the last 365 days are written with the sync identifier
  `healthy-eating:<weigh-in id>` and the weigh-in's `updated_at` (ms) as sync version, so a
  correction replaces the sample, a server deletion deletes it, and the import skips the app's
  own samples. `written` (UserDefaults) remembers the version in Apple Health, so a replaced
  sample (reported deleted with its old version) never deletes the weigh-in. The anchor moves on
  only when everything reached the server; an empty first read keeps no anchor (Apple Health
  returns nothing while read access is off). Weight tracking off skips the weight part. Turning it off
  or signing out forgets the anchor and `written`; data already synced stays on both sides.
  Placeholder launches use `PlaceholderAppleHealthStore` (three weigh-ins, no HealthKit).
- Offline (ios#20, `Core/Storage/ResponseCache.swift`, G1): `APIClient` keeps the last answer of
  every GET request on the device (Application Support, one folder per server, file protection
  until first unlock, excluded from backups) and returns it when the server can't be reached,
  telling `AppModel.cacheUsed` when it was saved; any answer from the server clears that. Every
  screen therefore works read-only offline. Today, History and Trends show `OfflineBanner`
  ("Offline. Showing data from 09:42. It updates when you are back online.") while
  `AppModel.offlineSince` is set; changes still need the server and fail as before. Today, History
  and Trends reload whenever the app comes back to the foreground (`AppModel.foregrounds`).
  Signing out, an ended session and deleting the account delete the cache.
- Widgets (ios#35, `HealthyEatingWidgets/TodayWidget.swift`, F1): one "Today" widget in four
  families, showing `TodaySnapshot` (today's totals, ranges, energy unit, Calm mode, last saved
  meal). The widget fetches it itself from `GET /api/v1/widget/today` with a read-only widget
  token (`Shared/WidgetAccess.swift`), asking for the next reload after 30 minutes (WidgetKit sets
  the real pace), and saves it; when the server can't be reached it shows the last snapshot, and a
  refused token is dropped. The app asks the server for that token (`POST /api/v1/widget-token`,
  `AppModel.ensureWidgetAccess`) after Today loads when it has none for this server, and never
  shares its own tokens. The app also writes the snapshot after Today loads, in background refresh
  (scheduled whenever signed in) and when Calm mode changes (`WidgetUpdates`); sign-out removes the
  snapshot and the widget token. Only a changed snapshot reloads the timeline; the timeline has a
  second entry at midnight, after which the widget says "Open Healthy Eating to update" until it
  has today's numbers. "Saved 20 min ago via Claude" has minute precision
  (`TodaySnapshot.savedLine`), kept current by a timeline entry every 10 minutes (entries cost no
  refresh budget); never the system timer, which shows seconds. Calm mode shows protein (and the other macros) instead
  of calories. Bars use the range band's look: no colors for over or under. The snapshot and the widget token are
  Keychain items in the access group `<team>.io.github.valtronforever.HealthyEating.shared`
  (`KeychainSnapshotStorage`; the app's Info.plist `SharedKeychainGroup` names it), because a
  free Apple developer team can't use App Groups but can share Keychain groups under its prefix.
  The app's entitlements list its own group first, so its tokens stay out of the shared group.
  The widget extension has no String Catalog yet (English only).
- Usual meals (ios#39, `Features/Dashboard/UsualMealsView.swift`, `GET /api/v1/usual-meals`,
  `POST /api/v1/meals/{id}/relog`): "Log a usual meal" on Today (under the meals, or under "No
  meals yet today") lists dishes eaten at least twice in 90 days; choosing one shows its values
  and provenance, a time (default now) and "Log meal". The server copies the meal (values,
  provenance, confidence) with the new time; the app sends a UUID it chose once per screen, so a
  repeated tap saves one meal. This is the only way the app adds a meal: it never creates meals
  from scratch. Calm mode hides the calories there too.
- Linked accounts (backend #20, `Features/Settings/LinkedAccountsView.swift`, opened from the
  account in Settings, `/api/v1/me/logins`): lists the Google, Microsoft or Apple accounts that
  sign in to this account (provider, email, last sign-in or when it was linked). The UI says
  "linked account", "Link an account" and "Unlink" (owner decision 2026-10-25); the API and code
  say "login". "Link an account" (`Core/Auth/LoginLinking.swift`) posts a PKCE
  challenge, opens the returned server page in the same web sheet as sign-in
  (`AppModel.webAuthenticator`; `PlaceholderWebAuthenticator` with placeholders, which "adds"
  Microsoft), reads `healthyeating://link/callback?code=…` (or `error=cancelled|expired`) and
  finishes with the code and verifier. An account that already signs in to another Healthy Eating
  account is reported in a neutral note (never an error, never merged); the only linked account
  has no Unlink (the server refuses it too). Unlinking asks for confirmation. Never linked by email.
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
- Keep the REST client in sync with the backend's `/api/v1`. If the API needs to change, change the backend first, then copy its `openapi.json` to `HealthyEatingTests/Fixtures/` and update the DTOs until `APIContractTests` pass.
- The REST client is hand-written (`URLSession`, no generator): DTOs spell out their snake_case `CodingKeys`, and request bodies send JSON `null` explicitly (`NSNull`) to clear a value; omitting a field means "no change".
- Tests that use `StubProtocol` go in `extension NetworkTests` (a serialized suite), because the stub has one global handler.
- Commit messages: imperative mood, short subject line.

## Do not

- Hardcode a server URL, client secret or provider credentials.
- Store tokens in `UserDefaults` or files.
- Add analytics, crash reporting or ad SDKs.
- Add dependencies with non-MIT-compatible licenses.
