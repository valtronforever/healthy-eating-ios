# Button

Four roles. One primary per screen.

- `primary` (`accent` fill, `on-accent` label): the single forward action ("Get started", "Continue", "Go to Today").
- `secondary` (`accent-soft` fill, `accent` label): helpful but optional ("Copy connection URL", "Turn on").
- `plain` (`accent` text): quiet actions inside content ("Mark day as complete", "Retry").
- `destructive` (`destructive` label on `surface-sunken`): irreversible actions only, and always followed by a confirmation.
- Props: `variant`, `block` (full width), `icon` (an SF Symbol name), `disabled`.
- SwiftUI: `.buttonStyle(.borderedProminent)` with `.tint(.accent)` and `.controlSize(.large)` for primary; `.bordered` for secondary; `role: .destructive` for delete.
