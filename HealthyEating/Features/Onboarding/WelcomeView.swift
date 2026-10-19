import SwiftUI

/// A1 Welcome: one sentence and three promises. The approved R4 icon is the only artwork.
struct WelcomeView: View {
    var onGetStarted: () -> Void

    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .largeTitle) private var iconSide: CGFloat = 96

    var body: some View {
        OnboardingScaffold {
            if let message = model.sessionEndedMessage {
                Banner(kind: .info, message: message)
            }
            Image("AppIconImage")
                .resizable()
                .frame(width: iconSide, height: iconSide)
                .clipShape(RoundedRectangle(cornerRadius: iconSide * 0.2237, style: .continuous))
                .padding(.top, Spacing.s6)
                .accessibilityLabel(Text("Healthy Eating app icon"))

            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("Healthy Eating")
                    .font(.title.bold())
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("A private dashboard for the meals you already log by talking to your AI assistant.")
                    .font(.body)
                    .foregroundStyle(.inkMuted)
            }

            VStack(alignment: .leading, spacing: Spacing.s5) {
                FeatureLine(systemName: "bubble.left", title: "Log in your chat",
                            text: "Tell Claude or ChatGPT what you ate. Nothing new to learn.")
                FeatureLine(systemName: "chart.bar", title: "See trends here",
                            text: "Weekly averages, target ranges and which values were estimated.")
                FeatureLine(systemName: "lock.shield", title: "Your data stays on your server",
                            text: "Open source and self-hosted. No ads, no tracking.")
            }
        } footer: {
            Button("Get started", action: onGetStarted)
                .buttonStyle(.action(.primary))
            Text("Free and open source (MIT)")
                .font(.footnote)
                .foregroundStyle(.inkMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.s1)
        }
    }
}

/// An icon tile with a short title and one line of explanation (A1, D3 off).
struct FeatureLine: View {
    let systemName: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            SymbolTile(systemName: systemName)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.ink)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    WelcomeView {}
}

#Preview("Dark") {
    WelcomeView {}.preferredColorScheme(.dark)
}

#Preview("AX5") {
    WelcomeView {}.environment(\.dynamicTypeSize, .accessibility5)
}
