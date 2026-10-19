import SwiftUI

/// E1 Settings (the parts that work without the backend): server, connection URL, Calm mode and
/// sign out. Account, targets, connected assistants, export and delete account need API endpoints.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                if let server = model.server {
                    Section {
                        LabeledContent("Address") {
                            Text(verbatim: CopyField.breakable(server.host))
                                .foregroundStyle(.inkMuted)
                                .accessibilityLabel(Text(verbatim: server.host))
                        }
                        CopyField(label: "Connection URL", value: server.mcpURL.absoluteString)
                            .padding(.vertical, Spacing.s1)
                    } header: {
                        Text("Server").sectionTextStyle()
                    }
                    .listRowBackground(Color.surface)
                }

                Section {
                    Toggle(isOn: $model.calmMode) {
                        HStack(spacing: Spacing.s3) {
                            SymbolTile(systemName: "eye.slash", small: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Calm mode").foregroundStyle(.ink)
                                Text("Hide calories everywhere")
                                    .font(.subheadline)
                                    .foregroundStyle(.inkMuted)
                            }
                        }
                    }
                    .tint(.accent)
                } header: {
                    Text("Display and privacy").sectionTextStyle()
                }
                .listRowBackground(Color.surface)

                Section {
                    Button("Sign out") { model.signOut() }
                        .foregroundStyle(.accent)
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("Healthy Eating \(appVersion) · MIT License")
                        .sectionTextStyle()
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
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
