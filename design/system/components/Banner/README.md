# Banner

A calm inline message at the top of a screen's content: offline with cached data, server unreachable, or a neutral note.

- Props: `kind` `'stale' | 'error' | 'info'`, `title`, `text`, `action` (a plain button label like "Retry").
- No red and no warning triangle, even for errors: state the fact, reassure about the data, offer one action.
- `stale` uses `surface-sunken`; `error` uses `surface` with a `line` outline; `info` uses `accent-soft`.
