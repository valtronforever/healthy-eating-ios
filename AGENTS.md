# AGENTS.md: healthy-eating-ios

Guidance for AI coding agents and contributors working in this repository.

## Project overview

Healthy Eating is an open-source (MIT), self-hostable app for tracking nutrition. It has two parts:

- **healthy-eating-backend** (separate repo): a Python service with an MCP server (food logging and nutrient calculation tools used from LLM clients), a REST API and an OAuth 2.1 authorization server with social login (Google, Microsoft, Apple). Data lives in PostgreSQL.
- **healthy-eating-ios** (this repo): a SwiftUI app where users sign in and see their **statistics and progress**: calories, macronutrients, vitamins and minerals over time.

Positioning: the private, honest dashboard for people who log food by talking to their AI assistant. The app is built around weekly trends and data provenance (which values were estimated, how confident), not per-meal precision. Main users already log food in ChatGPT or Claude; the second group is privacy-minded people and self-hosters.

Non-goals (do not build without an owner decision): own food database, barcode scanning, photo recognition, an in-app AI coach or chat, streaks, badges or social features, meal plans and recipes, exercise tracking, GLP-1 medication tracking.

In v1, food is logged through the MCP server from an LLM client. The app is primarily a viewer: it may edit and delete existing meals (edited values are no longer marked as estimated) and, later, re-log a meal that was already logged (copying its values and provenance), but it never creates meals from scratch. Body weight is optional and opt-in: it may be read from Apple Health or entered by hand, and when weight tracking is off no weight appears anywhere in the app. Do not build food recognition or nutrient calculation into the app; the backend owns that logic.

Status: early v1. The layout and commands below are the target structure. Create them as described when scaffolding, and keep this file in sync when they change.

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

## Target layout

```
HealthyEating/
  App/               # @main app, root navigation, dependency container
  Features/
    Onboarding/      # server URL entry, sign-in
    Dashboard/       # today's summary
    Statistics/      # trends, charts, nutrient detail
    Settings/        # account, linked logins, server, sign-out, delete account
  Core/
    Auth/            # OAuth discovery, client registration, PKCE, token refresh
    API/             # REST client, DTOs, error mapping
    Storage/         # Keychain, cache
    Models/          # domain models (separate from DTOs)
  Resources/         # assets, Localizable.xcstrings
HealthyEatingTests/
HealthyEatingUITests/
```

## Commands

```bash
open HealthyEating.xcodeproj
xcodebuild -scheme HealthyEating -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme HealthyEating -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Adjust the simulator name to one installed locally (`xcrun simctl list devices`). Before finishing any change, the project must build without warnings and tests must pass.

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

- The backend returns nutrients in canonical units (`kcal`, `g`, `mg`, `µg`). Format for display with `Measurement` and the user's locale; never re-compute nutrient values in the app.
- "Today" and daily charts use the user's local calendar day; send the IANA timezone to the backend where the API asks for it.
- **Neutral feedback is a hard rule.** Never use red, warnings or pop-ups for being over or under a target; show targets as ranges; no streaks, badges or gamification; no "good/bad food", "cheat" or "you went over" wording. Over and under are styled the same way.
- Show data provenance: values the user calculated vs values the assistant estimated, and the confidence.
- Every screen has loading, empty, and error states. The empty state for a new user explains how to connect the MCP server and shows the connection URL with a copy button.
- Support Dynamic Type, Dark Mode and VoiceOver labels on charts.
- All user-facing strings go through the String Catalog (`Localizable.xcstrings`).

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
