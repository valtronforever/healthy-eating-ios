import SwiftUI

/// The AI assistants with written connection steps. Menu names must be checked against current
/// Claude and ChatGPT releases. ChatGPT steps follow OpenAI's help article "Connecting custom MCP
/// servers in ChatGPT" (checked 2026-10-19): custom MCP servers are added on chatgpt.com under
/// Plugins, not in the apps. Saving meals works on a personal Pro plan (owner, 2026-10-19).
enum AssistantKind: String, CaseIterable, Identifiable {
    case claude, chatGPT, other

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .claude: "Claude"
        case .chatGPT: "ChatGPT"
        case .other: "Other"
        }
    }

    var steps: [LocalizedStringKey] {
        switch self {
        case .claude:
            ["In Claude, open Settings › Connectors.",
             "Choose Add custom connector and paste the URL.",
             "Sign in with the same account you use here.",
             "Send your first meal in any chat."]
        case .chatGPT:
            ["On a computer, open chatgpt.com/plugins.",
             "Select Add, then Add custom MCP server, and paste the URL.",
             "Accept the risk warning and select Create as a plugin.",
             "Sign in with the same account you use here.",
             "In a new chat, type @, choose Healthy Eating and send your meal."]
        case .other:
            ["Open your assistant’s MCP or connector settings.",
             "Add a remote MCP server with the URL above.",
             "Finish the sign-in in your browser.",
             "Ask it to log a meal."]
        }
    }

    /// What the assistant needs before the steps work, shown under them.
    var note: LocalizedStringKey? {
        switch self {
        case .chatGPT:
            "Custom MCP servers can only be added on the ChatGPT website, not in the ChatGPT apps. After that, Healthy Eating works in the apps too."
        case .claude, .other:
            nil
        }
    }

    /// Setup instructions to send to another device, for assistants that can't be set up on the phone.
    func shareText(mcpURL: URL) -> String? {
        switch self {
        case .chatGPT:
            String(localized: """
                Add Healthy Eating to ChatGPT:
                1. Open https://chatgpt.com/plugins
                2. Select Add, then Add custom MCP server.
                3. Name it Healthy Eating and paste this URL: \(mcpURL.absoluteString)
                4. Accept the risk warning, select Create as a plugin and sign in.
                """)
        case .claude, .other:
            nil
        }
    }
}

/// A4 Connect your AI assistant: the MCP connection URL, steps per assistant and a first message to try.
struct ConnectAssistantView: View {
    /// "I've connected it": wait for the first meal (A5).
    var onConnected: () -> Void = {}

    @Environment(AppModel.self) private var model
    @State private var assistant: AssistantKind = .claude

    var body: some View {
        OnboardingScaffold {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("Connect your AI assistant")
                    .font(.title2Bold)
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Add Healthy Eating to the assistant you already use. Your chats stay the same.")
                    .font(.callout)
                    .foregroundStyle(.ink)
            }

            if let server = model.server {
                CopyField(label: "Connection URL", value: server.mcpURL.absoluteString)
            }

            ConnectionSteps(assistant: $assistant, mcpURL: model.server?.mcpURL)

            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Try this first message")
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
                CopyField(value: String(localized: "Log my breakfast: oatmeal with berries"), buttonTitle: "Copy message", isCode: false)
            }
        } footer: {
            Button("I’ve connected it", action: onConnected)
                .buttonStyle(.action(.primary))
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") { model.completeOnboarding() }
            }
        }
    }
}

/// The assistant switch and its numbered steps (also shown from Today and Settings later).
struct ConnectionSteps: View {
    @Binding var assistant: AssistantKind
    /// Shown in the setup text the person can send to their computer.
    var mcpURL: URL?
    @ScaledMetric(relativeTo: .body) private var numberSide: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Picker("Assistant", selection: $assistant) {
                ForEach(AssistantKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: Spacing.s3) {
                ForEach(Array(assistant.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
                        Text(index + 1, format: .number)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.accent)
                            .frame(width: numberSide, height: numberSide)
                            .background(Color.accentSoft, in: Circle())
                            .accessibilityHidden(true)
                        Text(step)
                            .font(.body)
                            .foregroundStyle(.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if let note = assistant.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let mcpURL, let text = assistant.shareText(mcpURL: mcpURL) {
                ShareLink(item: text, subject: Text("Add Healthy Eating to ChatGPT")) {
                    Label("Share setup link", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.action(.secondary))
            }
        }
    }
}

#Preview("Light") {
    NavigationStack { ConnectAssistantView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { ConnectAssistantView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { ConnectAssistantView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
