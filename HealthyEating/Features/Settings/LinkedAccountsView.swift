import SwiftUI

/// Linked accounts (#20), opened from the account in Settings: the Google, Microsoft or Apple
/// accounts that sign in to this Healthy Eating account, "Link an account" through the server's
/// page in the web sheet (`LoginLinking`) and Unlink with a confirmation. Never linked by email,
/// Healthy Eating accounts are never merged, and the only linked account stays.
struct LinkedAccountsView: View {
    /// Called after an account was linked or unlinked, so Settings shows the new list.
    var onChange: () -> Void = {}

    @Environment(AppModel.self) private var app
    @State private var state: Loadable<[Login]> = .loading
    @State private var removing: Login?
    @State private var adding = false
    @State private var notice: String?
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
            case .loaded(let logins):
                if let error {
                    Banner(kind: .error, message: error.message).plainListRow()
                }
                if let notice {
                    Banner(kind: .info, message: notice).plainListRow()
                }
                Section {
                    ForEach(logins) { login in
                        row(login, removable: logins.count > 1)
                    }
                } footer: {
                    Text("Sign in with any of these, in this app or in your assistant, to reach the same data.")
                        .sectionTextStyle()
                }
                .listRowBackground(Color.surface)

                Section {
                    Button("Link an account") { Task { await add() } }
                        .buttonStyle(.action(.secondary))
                        .disabled(adding)
                        .accessibilityIdentifier("linkAccount")
                        .plainListRow()
                } footer: {
                    Text("Link another Google, Microsoft or Apple account. An account that already signs in to another Healthy Eating account is not linked; Healthy Eating accounts are never merged.")
                        .sectionTextStyle()
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Linked accounts")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task { await reload() }
        .alert(
            Text("Unlink the \(removing?.providerName ?? "") account?"),
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            presenting: removing
        ) { login in
            Button("Cancel", role: .cancel) {}
            Button("Unlink", role: .destructive) { Task { await remove(login) } }
        } message: { login in
            Text("You can no longer sign in with \(login.email ?? login.providerName). Your data stays on your server.")
        }
    }

    private func row(_ login: Login, removable: Bool) -> some View {
        HStack(spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: login.providerName).foregroundStyle(.ink)
                if let email = login.email {
                    Text(verbatim: email).font(.subheadline).foregroundStyle(.inkMuted)
                }
                Text(verbatim: Self.detail(login)).font(.footnote).foregroundStyle(.inkMuted)
            }
            Spacer()
            if removable {
                Button("Unlink") { removing = login }
                    .buttonStyle(ActionButtonStyle(variant: .destructive, block: false))
                    .accessibilityIdentifier("unlinkAccount")
            }
        }
    }

    /// "Last sign-in yesterday at 09:42", or "Added Oct 12, 2026" for a login not used yet.
    nonisolated static func detail(_ login: Login, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if let last = login.lastLoginAt {
            return String(localized: "Last sign-in \(RelativeTimeFormat.string(for: last, now: now, calendar: calendar, locale: locale))")
        }
        let day = login.createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
        return String(localized: "Added \(day)")
    }

    /// The neutral note after adding; nil when the person cancelled.
    nonisolated static func notice(for result: LinkResult, added: Login?) -> String? {
        switch result {
        case .linked:
            guard let added else { return String(localized: "Account linked. You can sign in with it from now on.") }
            return String(localized: "\(added.providerName) account linked. You can sign in with it from now on.")
        case .alreadyLinked:
            return String(localized: "This account was already linked.")
        case .otherAccount:
            return String(localized: "This account already signs in to another Healthy Eating account, so it was not linked. Healthy Eating accounts are never merged.")
        case .cancelled:
            return nil
        }
    }

    private func reload() async {
        guard let data = app.data else { return }
        do throws(APIError) {
            state = .loaded(try await data.logins())
        } catch {
            if state.value == nil { state = .failed(error) }
            app.handle(error)
        }
    }

    private func add() async {
        guard let data = app.data else { return }
        adding = true
        defer { adding = false }
        let before = Set(state.value?.map(\.id) ?? [])
        do throws(APIError) {
            let result = try await LoginLinking.addLogin(data: data, authenticator: app.webAuthenticator)
            error = nil
            guard result != .cancelled else { return }
            await reload()
            let added = state.value?.first { !before.contains($0.id) }
            notice = Self.notice(for: result, added: added)
            if result == .linked { onChange() }
        } catch {
            notice = nil
            self.error = error
            app.handle(error)
        }
    }

    private func remove(_ login: Login) async {
        guard let data = app.data else { return }
        do throws(APIError) {
            try await data.deleteLogin(login.id)
            error = nil
            notice = nil
            await reload()
            onChange()
        } catch {
            self.error = error
            app.handle(error)
        }
    }
}

#Preview("Light") {
    NavigationStack { LinkedAccountsView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { LinkedAccountsView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { LinkedAccountsView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
