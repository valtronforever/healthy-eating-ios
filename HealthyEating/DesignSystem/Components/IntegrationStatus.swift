import SwiftUI

/// The always-visible footnote that tells the person whether the connection to their assistant
/// works, as a fact with a time. Never alarming. See design/system/components/IntegrationStatus.
struct IntegrationStatus: View {
    enum Kind {
        /// A meal arrived recently: filled `accent` dot.
        case ok
        /// No meals for a while: hollow dot, a plain fact.
        case quiet
        /// Before the first meal: gray dot.
        case unknown
    }

    let state: Kind
    let text: LocalizedStringKey

    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 8

    var body: some View {
        HStack(spacing: Spacing.s2) {
            dot
                .frame(width: dotSize, height: dotSize)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.inkMuted)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var dot: some View {
        switch state {
        case .ok: Circle().fill(Color.accent)
        case .quiet: Circle().strokeBorder(Color.lineStrong, lineWidth: 1.5)
        case .unknown: Circle().fill(Color.lineStrong)
        }
    }
}

#Preview("Light") {
    IntegrationStatusGallery().previewCard()
}

#Preview("Dark") {
    IntegrationStatusGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    IntegrationStatusGallery().previewCard().environment(\.dynamicTypeSize, .accessibility5)
}

struct IntegrationStatusGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            IntegrationStatus(state: .ok, text: "Last meal saved \(RelativeTimeFormat.string(for: SampleData.lastSavedAt)) via \(SampleData.lastSavedVia)")
            IntegrationStatus(state: .quiet, text: "No meals saved in the last 2 days")
            IntegrationStatus(state: .unknown, text: "No meals received yet")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
