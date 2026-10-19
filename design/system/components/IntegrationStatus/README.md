# IntegrationStatus

One footnote line that tells the person whether the connection to their assistant works.

- Props: `state` `'ok' | 'quiet' | 'unknown'`, `text`.
- `ok`: filled `accent` dot, "Last meal saved 2 h ago via Claude". `quiet`: hollow dot, a plain fact ("No meals saved in the last 2 days"). `unknown`: gray dot before the first meal.
- Never alarming: no red, no exclamation marks. Tapping it opens Connected assistants (E2).
- Relative times: "just now", "20 min ago", "2 h ago", "yesterday at 19:30".
