import SwiftUI

/// G1 "offline with cached data" (ios#20): shown above a screen's content while it shows answers
/// kept on the device because the server can't be reached. Calm: says what is shown and that it
/// updates by itself; nothing to do.
struct OfflineBanner: View {
    @Environment(AppModel.self) private var app
    /// Space below it, for lists whose rows have none.
    var bottomSpacing: CGFloat = 0

    var body: some View {
        if let since = app.offlineSince {
            Banner(kind: .stale, message: String(localized: "Offline"), detail: Self.text(savedAt: since))
                .accessibilityIdentifier("offlineBanner")
                .padding(.bottom, bottomSpacing)
        }
    }

    /// "Showing data from 09:42. …" today, "Showing data from Oct 21, 09:42. …" before.
    nonisolated static func text(savedAt: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let style = calendar.isDate(savedAt, inSameDayAs: now)
            ? Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute()
            : Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day().hour().minute()
        let when = savedAt.formatted(style)
        return String(localized: "Showing data from \(when). It updates when you are back online.")
    }
}

#Preview("Light") {
    OfflineBanner().padding()
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    OfflineBanner().padding()
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    OfflineBanner().padding()
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
