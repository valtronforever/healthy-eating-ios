import SwiftUI

/// The connection steps after onboarding, to read again at any time: from Settings › Connected
/// assistants (Add another) and from Today's connect card. The same content as A4: the connection
/// URL, the steps per assistant and a first message to try.
struct ConnectionGuideView: View {
    let server: ServerAddress?
    @State private var assistant: AssistantKind

    init(server: ServerAddress?, assistant: AssistantKind = .claude) {
        self.server = server
        _assistant = State(initialValue: assistant)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Add Healthy Eating to the assistant you already use. Your chats stay the same.")
                    .font(.callout)
                    .foregroundStyle(.ink)
                if let server {
                    CopyField(label: "Connection URL", value: server.mcpURL.absoluteString)
                }
                ConnectionSteps(assistant: $assistant, mcpURL: server?.mcpURL)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text("Try this first message")
                        .font(.footnote)
                        .foregroundStyle(.inkMuted)
                    CopyField(value: String(localized: "Log my breakfast: oatmeal with berries"), buttonTitle: "Copy message", isCode: false)
                }
            }
            .padding(Spacing.s4)
        }
        .background(Color.bg)
        .navigationTitle("Connection guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Light") {
    NavigationStack { ConnectionGuideView(server: try? ServerAddress.parse("https://food.example.com")) }
}

#Preview("Dark") {
    NavigationStack { ConnectionGuideView(server: try? ServerAddress.parse("https://food.example.com"), assistant: .chatGPT) }
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { ConnectionGuideView(server: try? ServerAddress.parse("https://food.example.com")) }
        .environment(\.dynamicTypeSize, .accessibility5)
}
