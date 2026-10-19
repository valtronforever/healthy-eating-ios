# ListRow

A row in an inset grouped list (Settings, Meal detail, Connected assistants).

- Props: `title`, `subtitle`, `value` (shown right in `ink-muted`, adds a chevron), `accessory` `'chevron' | 'toggle' | 'none'`, `on` (toggle state), `accent` (action row in `accent`), `destructive` (label in `destructive`).
- Wrap rows in `.he-list` (SwiftUI `List` with `.listStyle(.insetGrouped)`); section headers and footers use `.he-section-title` / `.he-section-foot`.
- Toggles are system `Toggle` with `.tint(.accent)`; their off state has a `line-strong` outline so it reads at 3:1.
