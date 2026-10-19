# TextField

A labeled single-line input for the few places the app takes typing: the server address (A2) and the DELETE confirmation (E3).

- Props: `label`, `value`, `placeholder`, `hint`, `error`, `focused`, `mono` (SF Mono for URLs).
- Border `line-strong` (3:1) at rest, 2 pt `accent` when focused.
- Errors use a 2 pt `ink` border, an `exclamationmark.circle` and a short sentence in `ink`, announced to VoiceOver. Never red: a mistyped address is not an alarm. Copy: "Use an https address".
- SwiftUI: `TextField` with `.textContentType(.URL)`, `.keyboardType(.URL)`, `.autocorrectionDisabled()` and `.textInputAutocapitalization(.never)` for the server address.
