import SwiftUI

/// E2 Connected assistants: every AI assistant and app signed in to the account, when it was
/// last used, and Revoke with a confirmation. Revoking this iPhone signs the app out.
struct ConnectedAssistantsView: View {
    @Environment(AppModel.self) private var app
    @State private var state: Loadable<[Connection]> = .loading
    @State private var revoking: (connection: Connection, signIn: Connection.SignIn)?
    @State private var error: APIError?

    var body: some View {
        List {
            switch state {
            case .loading:
                LoadingCards().plainListRow()
            case .failed(let error):
                ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                    .padding(.top, Spacing.s6)
                    .plainListRow()
            case .loaded(let connections):
                if let error {
                    Banner(kind: .error, message: error.message).plainListRow()
                }
                Section {
                    if connections.isEmpty {
                        Text("Nothing is connected yet.").foregroundStyle(.inkMuted)
                    }
                    ForEach(connections) { connection in
                        ForEach(connection.signIns) { signIn in
                            row(connection, signIn)
                        }
                    }
                } footer: {
                    Text("Revoking signs that assistant out of your server. Meals it already saved stay, and you can connect it again at any time.")
                        .sectionTextStyle()
                }
                .listRowBackground(Color.surface)

                if let server = app.server {
                    Section {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            Text("Add this URL to your assistant (a connector in Claude, a plugin in ChatGPT):").foregroundStyle(.ink)
                            CopyField(value: server.mcpURL.absoluteString)
                        }
                        // The separator would start at the Copy button's label; keep it full width.
                        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                        // The A4 steps, to read again after onboarding (Claude, ChatGPT and Other inside).
                        NavigationLink {
                            ConnectionGuideView(server: server)
                        } label: {
                            Text("Connection guide").foregroundStyle(.ink)
                        }
                        .accessibilityIdentifier("connectionGuide")
                    } header: {
                        Text("Add another").sectionTextStyle()
                    }
                    .listRowBackground(Color.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Connected assistants")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task { await reload() }
        .alert(
            Text("Revoke \(revoking?.connection.name ?? String(localized: "this assistant"))?"),
            isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }),
            presenting: revoking
        ) { item in
            Button("Cancel", role: .cancel) {}
            Button("Revoke", role: .destructive) { Task { await revoke(item.signIn) } }
        } message: { item in
            if item.signIn.isCurrent {
                Text("This signs this iPhone out of \(app.server?.host ?? ""). Your data stays on your server.")
            } else {
                Text("\(item.connection.name ?? String(localized: "It")) can no longer save meals to \(app.server?.host ?? ""). Meals it already saved stay.")
            }
        }
    }

    private func row(_ connection: Connection, _ signIn: Connection.SignIn) -> some View {
        HStack(spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: connection.name ?? String(localized: "Unnamed assistant")).foregroundStyle(.ink)
                Text(verbatim: detail(signIn)).font(.subheadline).foregroundStyle(.inkMuted)
            }
            Spacer()
            if !signIn.isCurrent {
                Button("Revoke") { revoking = (connection, signIn) }
                    .buttonStyle(ActionButtonStyle(variant: .destructive, block: false))
            }
        }
    }

    private func detail(_ signIn: Connection.SignIn) -> String {
        if signIn.isCurrent { return String(localized: "This iPhone · now") }
        guard let used = signIn.lastUsedAt else { return String(localized: "Not used yet") }
        return String(localized: "Last used \(RelativeTimeFormat.string(for: used))")
    }

    private func reload() async {
        guard let data = app.data else { return }
        do throws(APIError) {
            state = .loaded(try await data.connections())
        } catch {
            if state.value == nil { state = .failed(error) }
            app.handle(error)
        }
    }

    private func revoke(_ signIn: Connection.SignIn) async {
        guard let data = app.data else { return }
        do throws(APIError) {
            if try await data.revoke(signIn: signIn.id) {
                await app.signOut()
                return
            }
            error = nil
            await reload()
        } catch {
            self.error = error
            app.handle(error)
        }
    }
}

#Preview("Light") {
    NavigationStack { ConnectedAssistantsView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { ConnectedAssistantsView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { ConnectedAssistantsView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
