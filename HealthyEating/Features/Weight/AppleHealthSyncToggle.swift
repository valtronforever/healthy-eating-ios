import SwiftUI

/// "Sync with Apple Health" (ios#31, ios#32), in Settings and on D3. Turning it on shows the
/// system's access sheet once and syncs right away; after that meals go to Apple Health and
/// weigh-ins sync both ways whenever the app opens (and in background refresh). Off by default,
/// per device.
struct AppleHealthSyncToggle: View {
    @Environment(AppModel.self) private var app
    /// Called after a sync, so the screen can show the new weigh-ins.
    var onSync: () -> Void = {}

    var body: some View {
        Toggle(isOn: Binding(
            get: { app.appleHealthSyncEnabled },
            set: { on in
                Task {
                    await app.setAppleHealthSync(on)
                    onSync()
                }
            })) {
            HStack(spacing: Spacing.s3) {
                SymbolTile(systemName: "heart.text.square", small: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync with Apple Health").foregroundStyle(.ink)
                    Text(verbatim: Self.detail(enabled: app.appleHealthSyncEnabled, last: app.appleHealthLastSync,
                                               count: app.appleHealthLastSyncCount))
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
            }
        }
        .accessibilityIdentifier("appleHealthSync")
    }

    /// "Meals and body weight, when the app opens", or what the last sync changed.
    nonisolated static func detail(enabled: Bool, last: Date?, count: Int, locale: Locale = .current) -> String {
        guard enabled, let last, count > 0 else { return String(localized: "Meals and body weight, when the app opens") }
        let when = last.formatted(.relative(presentation: .named).locale(locale))
        return count == 1 ? String(localized: "1 change synced \(when)")
            : String(localized: "\(count) changes synced \(when)")
    }
}

#Preview("Light") {
    List { AppleHealthSyncToggle() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    List { AppleHealthSyncToggle() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    List { AppleHealthSyncToggle() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
