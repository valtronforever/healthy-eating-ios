import SwiftUI

/// A calm, centered message that replaces a screen's content: server unreachable, signed out,
/// nothing to show yet (G1). No red and no warning symbol: state the fact, reassure about the
/// data, offer one primary action. Pass host names in `title` through `CopyField.breakable`, so
/// they wrap at dots instead of being hyphenated at large text sizes.
struct StateMessage: View {
    let systemImage: String
    let title: String
    let message: String
    var primaryTitle: LocalizedStringKey?
    var primarySystemImage: String?
    var primaryAction: (() -> Void)?
    var secondaryTitle: LocalizedStringKey?
    var secondaryAction: (() -> Void)?
    /// A technical detail in small print, e.g. "Details: connection timed out after 10 s".
    var detail: String?

    @ScaledMetric(relativeTo: .largeTitle) private var circle: CGFloat = 104

    var body: some View {
        VStack(spacing: Spacing.s4) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.accent)
                .frame(width: circle, height: circle)
                .background(Color.accentSoft, in: Circle())
                .padding(.bottom, Spacing.s2)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3Semibold)
                .foregroundStyle(.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .foregroundStyle(.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let primaryTitle, let primaryAction {
                Button(action: primaryAction) {
                    if let primarySystemImage {
                        Label(primaryTitle, systemImage: primarySystemImage)
                    } else {
                        Text(primaryTitle)
                    }
                }
                .buttonStyle(ActionButtonStyle(variant: .primary))
                .padding(.top, Spacing.s2)
            }
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(ActionButtonStyle(variant: .plain))
            }
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.s5)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Light") {
    StateMessageGallery().padding().background(Color.bg)
}

#Preview("Dark") {
    StateMessageGallery().padding().background(Color.bg).preferredColorScheme(.dark)
}

#Preview("AX5") {
    ScrollView { StateMessageGallery().padding() }.background(Color.bg)
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct StateMessageGallery: View {
    var body: some View {
        StateMessage(
            systemImage: "server.rack",
            title: String(localized: "Can’t reach \(CopyField.breakable("food.example.com"))"),
            message: "Check that your server is running and that you are online. Your data is safe on your server.",
            primaryTitle: "Retry", primarySystemImage: "arrow.clockwise", primaryAction: {},
            secondaryTitle: "Check server address", secondaryAction: {},
            detail: "Details: connection timed out after 10 s")
    }
}
