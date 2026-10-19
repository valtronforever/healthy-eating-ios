import SwiftUI

/// A2 Server: the address of the person's own Healthy Eating server. Continue stays disabled
/// until something is typed; a non-https address shows a calm inline error (no red).
struct ServerView: View {
    var onContinue: () -> Void

    @Environment(AppModel.self) private var model
    @State private var address = ""
    @State private var error: ServerAddress.ValidationError?

    var body: some View {
        OnboardingScaffold {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("Your server")
                    .font(.title2Bold)
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Enter the address of your Healthy Eating server. It is the same one you connect to your AI assistant.")
                    .font(.callout)
                    .foregroundStyle(.ink)
            }

            LabeledTextField(
                label: "Server address", text: $address, placeholder: "https://food.example.com",
                hint: "Ask whoever runs your server if you are not sure.",
                error: error?.message, isURL: true, identifier: "serverAddress", onSubmit: submit)
                .onChange(of: address) { error = nil }

            if error == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Running your own?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.ink)
                    Text("Healthy Eating is the app plus a PostgreSQL database on any server you control. Setup takes about 15 minutes.")
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                    if let guide = URL(string: "https://github.com/valtronforever/healthy-eating-backend#readme") {
                        Link("Read the self-hosting guide", destination: guide)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.accent)
                            .frame(minHeight: Spacing.tapTarget)
                    }
                }
                .cardStyle()
            }
        } footer: {
            Button("Continue", action: submit)
                .buttonStyle(.action(.primary))
                .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        do {
            let server = try ServerAddress.parse(address)
            model.setServer(server)
            onContinue()
        } catch {
            self.error = error
        }
    }
}

#Preview("Light") {
    NavigationStack { ServerView {} }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.resetOnboarding]))
}

#Preview("Dark") {
    NavigationStack { ServerView {} }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.resetOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { ServerView {} }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.resetOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
