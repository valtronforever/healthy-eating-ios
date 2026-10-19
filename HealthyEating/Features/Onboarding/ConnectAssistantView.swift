import SwiftUI

/// The AI assistants with written connection steps. Menu names must be checked against current
/// Claude and ChatGPT releases.
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
            ["In ChatGPT, open Settings › Connectors.",
             "Add a custom connector and paste the URL.",
             "Sign in with the same account you use here.",
             "Send your first meal in any chat or project."]
        case .other:
            ["Open your assistant’s MCP or connector settings.",
             "Add a remote MCP server with the URL above.",
             "Finish the sign-in in your browser.",
             "Ask it to log a meal."]
        }
    }
}

/// A4 Connect your AI assistant: the MCP connection URL, steps per assistant and a first message to try.
struct ConnectAssistantView: View {
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

            ConnectionSteps(assistant: $assistant)

            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("Try this first message")
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
                CopyField(value: String(localized: "Log my breakfast: oatmeal with berries"), buttonTitle: "Copy message", isCode: false)
            }
        } footer: {
            Button("I’ve connected it") { model.completeOnboarding() }
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
