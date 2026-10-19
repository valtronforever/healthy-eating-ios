# CopyField

A read-only URL in monospace with a Copy button that confirms in place ("Copied", then back).

- Props: `label`, `value`.
- Used for the MCP connection URL in Connect your AI assistant (A4), the new-user empty state (B2) and Settings.
- The value wraps rather than truncates, so the person can read the whole address.
- SwiftUI: `Text(url).font(.subheadline.monospaced()).textSelection(.enabled)` plus a `Button` that writes to `UIPasteboard` and announces "Copied".
