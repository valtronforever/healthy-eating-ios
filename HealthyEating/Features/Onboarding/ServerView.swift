import SwiftUI

/// A2 Server: the address of the person's own Healthy Eating server. Continue stays disabled
/// until something is typed; a non-https address shows a calm inline error (no red).
/// Continue then signs in through the server's login page in the system web sheet (A3).
struct ServerView: View {
    var onContinue: () -> Void

    @Environment(AppModel.self) private var model
    @State private var address = ""
    @State private var error: ServerAddress.ValidationError?
    @State private var signInError: AuthError?
    @State private var isSigningIn = false

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
                .onChange(of: address) {
                    error = nil
                    signInError = nil
                }

            if let signInError {
                Banner(kind: .error, message: signInError.message,
                       detail: signInError.detail.map { String(localized: "Details: \($0)") })
            }

            if error == nil, signInError == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Running your own?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.ink)
                    Text("Healthy Eating is the app plus a PostgreSQL database on any server you control. Setup takes about 15 minutes.")
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                    if let guide = URL(string: "https://github.com/valtronforever/healthy-eating-backend/blob/main/docs/self-hosting.md") {
                        Link("Read the self-hosting guide", destination: guide)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.accent)
                            .frame(minHeight: Spacing.tapTarget)
                    }
                }
                .cardStyle()
            }
        } footer: {
            Button(action: submit) {
                if isSigningIn {
                    HStack(spacing: Spacing.s2) {
                        ProgressView().tint(.onAccent)
                        Text("Signing in")
                    }
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.action(.primary))
            .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isSigningIn)
            Text("You sign in on your server’s page. An account is created the first time.")
                .font(.footnote)
                .foregroundStyle(.inkMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.s1)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        let server: ServerAddress
        do {
            server = try ServerAddress.parse(address)
        } catch {
            self.error = error
            return
        }
        model.setServer(server)
        if model.isSignedIn {
            onContinue()
            return
        }
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do throws(AuthError) {
                try await model.signIn()
                onContinue()
            } catch .cancelled {
                // Closing the sheet is a choice, not an error.
            } catch {
                signInError = error
            }
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
