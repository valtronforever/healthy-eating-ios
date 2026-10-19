import SwiftUI

/// How sure the assistant was about an estimate: three rising pips plus Low, Medium or High.
/// The same neutral colors for every level: low confidence is information, not a warning.
/// See design/system/components/ConfidenceIndicator.
struct ConfidenceIndicator: View {
    let level: Confidence
    /// Drops the word "confidence" (meal rows). Meal detail keeps it.
    var short = false

    @ScaledMetric(relativeTo: .caption) private var pipWidth: CGFloat = 3
    @ScaledMetric(relativeTo: .caption) private var pipUnit: CGFloat = 2

    var body: some View {
        HStack(spacing: 5) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(1...3, id: \.self) { step in
                    pip(filled: step <= filledCount)
                        .frame(width: pipWidth, height: pipUnit * CGFloat(2 + step))
                }
            }
            .accessibilityHidden(true)
            (short ? shortTitle : longTitle)
                .font(.caption1Medium)
                .foregroundStyle(.inkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(longTitle)
    }

    private var filledCount: Int {
        switch level {
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }

    @ViewBuilder
    private func pip(filled: Bool) -> some View {
        let shape = Capsule(style: .continuous)
        if filled {
            shape.fill(Color.inkMuted)
        } else {
            shape.fill(Color.surfaceSunken).overlay(shape.strokeBorder(Color.lineStrong, lineWidth: 1))
        }
    }

    private var shortTitle: Text {
        switch level {
        case .low: Text("Low")
        case .medium: Text("Medium")
        case .high: Text("High")
        }
    }

    private var longTitle: Text {
        switch level {
        case .low: Text("Low confidence")
        case .medium: Text("Medium confidence")
        case .high: Text("High confidence")
        }
    }
}

#Preview("Light") {
    ConfidenceIndicatorGallery().previewCard()
}

#Preview("Dark") {
    ConfidenceIndicatorGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    ConfidenceIndicatorGallery().previewCard().environment(\.dynamicTypeSize, .accessibility5)
}

struct ConfidenceIndicatorGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            ForEach(Confidence.allCases, id: \.self) { level in
                ConfidenceIndicator(level: level)
            }
            ConfidenceIndicator(level: .medium, short: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
