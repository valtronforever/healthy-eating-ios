# Project context for the icon study

Snapshot: 2026-10-18. Sources: workspace AGENTS.md and APP_STATE.md, iOS AGENTS.md,
local repository contents/git status, and issue #42 retrieved with `gh issue view`.

Healthy Eating is an MIT, self-hostable nutrition tracker. People log food in the AI
assistant they already use. That assistant sends structured meal values to their own
Python/PostgreSQL backend through MCP. The iOS app presents history, statistics and progress;
it may edit/delete an existing meal, but does not create new meals from scratch.

Primary audience: existing conversational food loggers. Secondary audience: privacy-minded
people and self-hosters. Positioning: a private, honest dashboard. Weekly trends and explicit
provenance matter more than implied per-meal precision. Tone is calm and neutral; no scores,
streaks, moral food labels, body imagery or warning colors for target deviations.

Verified local baseline before this work:

- Backend `main` at `b272bc4`, matching local `origin/main`; clean working tree.
- iOS `main` at `b187f96`, matching local `origin/main`; clean working tree. Tracked files:
  `AGENTS.md` and `LICENSE`. There is no Swift code or Xcode project yet.
- APP_STATE describes implemented OAuth/social sign-in, MCP `get_profile`/`log_meal`, meal
  storage and `/api/v1/me`. Meal/statistics REST endpoints and the iOS app remain planned.
  Backend tests were not rerun for this icon-only task; the 58-test result in APP_STATE is
  a previously recorded verification, not a new result.
- The iOS target stack is Swift 6/SwiftUI, native frameworks, iOS 18 minimum (subject to
  later review). The app name can change, so the icon contains no text.

Owner's scope for this task: prepare and attach all app-icon design assets to issue #42;
exclude the Claude Design part. Ten concepts, four refinements, the selected three
appearance masters, PNG exports, comparison canvas, concept PDF and icon-only design notes
are included. The owner selected concept 08 on 2026-10-18, then requested a kitchen knife and a centered
utensil pair; the current masters implement **R4 / Fork + knife conversation**. Commits, screen
design and app integration remain pending.
