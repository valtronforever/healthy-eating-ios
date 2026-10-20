import SwiftUI

/// Loads what Settings shows from the server: the account, settings and connections.
@MainActor
@Observable
final class SettingsModel {
    struct Snapshot {
        var account: Account
        var settings: UserSettings
        var connections: [Connection]
    }

    private(set) var state: Loadable<Snapshot> = .loading
    private(set) var saveError: APIError?

    func load(_ data: any NutritionDataSource) async -> APIError? {
        do {
            async let account = data.account()
            async let settings = data.settings()
            async let connections = data.connections()
            state = .loaded(Snapshot(account: try await account, settings: try await settings, connections: try await connections))
            return nil
        } catch {
            let apiError = error as? APIError ?? .unexpectedResponse(String(describing: error))
            if state.value == nil { state = .failed(apiError) }
            return apiError
        }
    }

    func update(_ change: APIClient.SettingsChange, _ data: any NutritionDataSource) async -> APIError? {
        do throws(APIError) {
            let settings = try await data.updateSettings(change)
            if case .loaded(var snapshot) = state {
                snapshot.settings = settings
                state = .loaded(snapshot)
            }
            saveError = nil
            return nil
        } catch {
            saveError = error
            return error
        }
    }
}

/// E1 Settings: the account, server and time zone, energy unit and target ranges, connected
/// assistants, Calm mode, export, licenses, sign out and delete account.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var model = SettingsModel()
    @State private var deletingAccount = false
    @State private var exportFormat: String?
    @State private var exportedFile: ExportedFile?
    @State private var exportError: APIError?

    struct ExportedFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            List {
                switch model.state {
                case .loading:
                    LoadingCards().plainListRow()
                case .failed(let error):
                    ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                        .padding(.top, Spacing.s6)
                        .plainListRow()
                    signOutSection
                case .loaded(let snapshot):
                    loaded(snapshot)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Settings")
            .refreshable { await reload() }
            .sheet(isPresented: $deletingAccount) {
                DeleteAccountView(host: app.server?.host ?? "", assistants: assistantCount, onExport: { Task { await export("json") } })
            }
            .sheet(item: $exportedFile) { file in
                ShareSheet(items: [file.url])
            }
        }
        .task { await reload() }
    }

    private var assistantCount: Int {
        model.state.value?.connections.filter { $0.kind == .aiAssistant }.count ?? 0
    }

    @ViewBuilder
    private func loaded(_ snapshot: SettingsModel.Snapshot) -> some View {
        @Bindable var app = app
        if let error = model.saveError ?? exportError {
            Banner(kind: .error, message: error.message).plainListRow()
        }

        Section {
            HStack(spacing: Spacing.s3) {
                Text(initials(snapshot.account))
                    .font(.headline)
                    .foregroundStyle(.accent)
                    .frame(width: 44, height: 44)
                    .background(Color.accentSoft, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: snapshot.account.displayName ?? snapshot.account.email ?? String(localized: "Your account"))
                        .foregroundStyle(.ink)
                    Text("Signed in with \(snapshot.account.loginsText)")
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
            }
        }
        .listRowBackground(Color.surface)

        Section {
            if let server = app.server {
                LabeledContent("Address") {
                    Text(verbatim: server.host).foregroundStyle(.inkMuted)
                }
                LabeledContent("Connection URL") {
                    Text(verbatim: CopyField.breakable(server.mcpURL.absoluteString))
                        .font(.code)
                        .foregroundStyle(.inkMuted)
                        .textSelection(.enabled)
                }
            }
            NavigationLink {
                TimeZoneView(current: snapshot.settings.timeZone) { identifier in
                    Task { await update(.init(timeZone: .some(identifier))) }
                }
            } label: {
                LabeledContent("Time zone") {
                    Text(verbatim: TimeZoneView.label(for: snapshot.settings.timeZone)).foregroundStyle(.inkMuted)
                }
            }
        } header: {
            Text("Server").sectionTextStyle()
        }
        .listRowBackground(Color.surface)

        Section {
            HStack {
                Text("Energy").foregroundStyle(.ink)
                Spacer(minLength: Spacing.s4)
                Picker("Energy", selection: Binding(
                    get: { snapshot.settings.energyUnit },
                    set: { unit in Task { await update(.init(energyUnit: unit)) } })) {
                    Text(verbatim: NutrientUnit.kcal.symbol).tag(EnergyUnit.kcal)
                    Text(verbatim: NutrientUnit.kilojoules.symbol).tag(EnergyUnit.kj)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            NavigationLink {
                TargetsView(settings: snapshot.settings) { change in
                    await update(change)
                }
            } label: {
                LabeledContent("Target ranges") {
                    Text(verbatim: targetSummary(snapshot.settings)).foregroundStyle(.inkMuted)
                }
            }
            .accessibilityIdentifier("targetRanges")
        } header: {
            Text("Units and targets").sectionTextStyle()
        }
        .listRowBackground(Color.surface)

        Section {
            NavigationLink {
                ConnectedAssistantsView()
            } label: {
                HStack(spacing: Spacing.s3) {
                    SymbolTile(systemName: "bubble.left", small: true)
                    LabeledContent("Connected assistants") {
                        Text(verbatim: "\(assistantCount)").foregroundStyle(.inkMuted)
                    }
                }
            }
            .accessibilityIdentifier("connectedAssistants")
        } header: {
            Text("Connections").sectionTextStyle()
        }
        .listRowBackground(Color.surface)

        Section {
            Toggle(isOn: $app.calmMode) {
                HStack(spacing: Spacing.s3) {
                    SymbolTile(systemName: "eye.slash", small: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calm mode").foregroundStyle(.ink)
                        Text("Hide calories everywhere").font(.subheadline).foregroundStyle(.inkMuted)
                    }
                }
            }
            Toggle(isOn: arrivalNotice) {
                HStack(spacing: Spacing.s3) {
                    SymbolTile(systemName: "bell", small: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notice when meals stop arriving").foregroundStyle(.ink)
                        Text("One quiet notification after 2 days").font(.subheadline).foregroundStyle(.inkMuted)
                    }
                }
            }
            .accessibilityIdentifier("arrivalNotice")
        } header: {
            Text("Display and privacy").sectionTextStyle()
        } footer: {
            if app.arrivalNoticeDeclined {
                Text("Notifications are off for Healthy Eating. Turn them on in the Settings app to get this notice.")
                    .sectionTextStyle()
            }
        }
        .listRowBackground(Color.surface)

        Section {
            Menu {
                Button("JSON") { Task { await export("json") } }
                Button("CSV (ZIP)") { Task { await export("csv") } }
            } label: {
                HStack(spacing: Spacing.s3) {
                    SymbolTile(systemName: "square.and.arrow.up", small: true)
                    LabeledContent("Export data") {
                        if exportFormat != nil {
                            ProgressView()
                        } else {
                            Text("JSON, CSV").foregroundStyle(.inkMuted)
                        }
                    }
                    .foregroundStyle(.ink)
                }
            }
            .disabled(exportFormat != nil)
            NavigationLink {
                LicensesView()
            } label: {
                HStack(spacing: Spacing.s3) {
                    SymbolTile(systemName: "info.circle", small: true)
                    Text("Open-source licenses").foregroundStyle(.ink)
                }
            }
        } header: {
            Text("Your data").sectionTextStyle()
        }
        .listRowBackground(Color.surface)

        signOutSection

        Section {
            Button("Delete account") { deletingAccount = true }
                .buttonStyle(.action(.destructive))
                .plainListRow()
        } footer: {
            Text("Healthy Eating \(appVersion) · MIT License")
                .sectionTextStyle()
                .frame(maxWidth: .infinity)
        }
    }

    private var arrivalNotice: Binding<Bool> {
        Binding(get: { app.arrivalNoticeEnabled }, set: { on in Task { await app.setArrivalNotice(on) } })
    }

    private var signOutSection: some View {
        Section {
            Button("Sign out") { Task { await app.signOut() } }
                .foregroundStyle(.accent)
                .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.surface)
    }

    private func initials(_ account: Account) -> String {
        let name = account.displayName ?? account.email ?? "?"
        let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(parts).uppercased()
    }

    private func targetSummary(_ settings: UserSettings) -> String {
        guard let calories = settings.targets[.calories], calories.min != nil || calories.max != nil else {
            return settings.targets.isEmpty ? String(localized: "Not set") : String(localized: "Set")
        }
        let unit = settings.energyUnit
        return NutritionFormat.shortTarget(
            min: calories.min.map(unit.amount(fromKcal:)), max: calories.max.map(unit.amount(fromKcal:)))
            + " " + unit.nutrientUnit.symbol
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func reload() async {
        guard let data = app.data else { return }
        if let error = await model.load(data) { app.handle(error) }
    }

    @discardableResult
    private func update(_ change: APIClient.SettingsChange) async -> APIError? {
        guard let data = app.data else { return nil }
        let error = await model.update(change, data)
        if let error { app.handle(error) }
        return error
    }

    private func export(_ format: String) async {
        guard let data = app.data else { return }
        exportFormat = format
        defer { exportFormat = nil }
        do throws(APIError) {
            exportedFile = ExportedFile(url: try await data.export(format: format))
            exportError = nil
        } catch {
            exportError = error
            app.handle(error)
        }
    }
}

/// The system share sheet, for the exported file.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview("Light") {
    SettingsView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    SettingsView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    SettingsView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
