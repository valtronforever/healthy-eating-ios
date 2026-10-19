# Healthy Eating for iOS

The native dashboard for the self-hosted Healthy Eating nutrition tracker. Food is logged through
an AI assistant connected to the backend's MCP server; the app shows trends, provenance and the
connection status.

Status: early scaffold. The app builds with the approved design system and onboarding (server
address and connection steps); sign-in and live data are not built yet, so data screens show
sample data. See [AGENTS.md](AGENTS.md) for the stack, layout, commands and product rules.

- [Design system spec](design/system/README.md): tokens, copy rules, component guidelines.
- [App icon package](design/README.md): the approved R4 Fork + knife conversation icon.

Requirements: Xcode 26 or later, iOS 18 or later.

```bash
open HealthyEating.xcodeproj
```

Licensed under [MIT](LICENSE).
