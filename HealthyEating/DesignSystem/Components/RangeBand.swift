import SwiftUI

/// A target shown as a band on a track, with the value as a thin bar that simply ends where it ends.
/// Over and under look identical: no color change, no icon, no "over" or "left" wording.
/// The target is always printed as text under the track; either bound may be open, and without
/// a target only the value bar is drawn. See design/system/components/RangeBand.
struct RangeBand: View {
    let label: String
    let value: Double
    let min: Double?
    let max: Double?
    var unit: NutrientUnit = .grams
    /// Macro color for the value bar and the dot; `nil` uses `ink`.
    var macro: Macro?
    /// Track end; defaults to 130% of `max` (or a little past the value if it is larger).
    var scaleMax: Double?
    /// Hides the label and value line (used under the hero number of the summary card).
    var compact = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var dotSize: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !compact {
                head
            }
            track
                .frame(height: trackHeight)
                .accessibilityHidden(true)
            Text(NutritionFormat.target(min: min, max: max, unit))
                .font(.footnote)
                .foregroundStyle(.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(NutritionFormat.spokenTarget(value: value, min: min, max: max, unit: unit))
    }

    private var head: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.s2))
        return layout {
            HStack(spacing: Spacing.s2) {
                if let macro {
                    Circle()
                        .fill(macro.color)
                        .frame(width: dotSize, height: dotSize)
                }
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: Spacing.s2)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(NutritionFormat.number(value))
                    .metricFont(.small)
                    .foregroundStyle(.ink)
                Text(unit.symbol)
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
            }
        }
    }

    private var track: some View {
        let reference = max ?? min ?? value
        let top = Swift.max(scaleMax ?? Swift.max(reference * 1.3, value * 1.05), 1)
        let barColor = macro?.color ?? Color.ink
        let low = min
        let high = max
        return Canvas { context, size in
            func x(_ v: Double) -> CGFloat { CGFloat(Swift.min(Swift.max(v / top, 0), 1)) * size.width }
            let trackShape = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: Radius.xs, style: .continuous)
            context.fill(trackShape, with: .color(.surfaceSunken))

            if low != nil || high != nil {
                let start = x(low ?? 0)
                let end = x(high ?? top)
                let bandRect = CGRect(x: start, y: 0, width: Swift.max(end - start, 0), height: size.height)
                context.fill(Path(bandRect), with: .color(.band))
                let edge: CGFloat = 2
                if low != nil {
                    context.fill(Path(CGRect(x: bandRect.minX, y: 0, width: edge, height: size.height)), with: .color(.accent))
                }
                if high != nil {
                    context.fill(Path(CGRect(x: bandRect.maxX - edge, y: 0, width: edge, height: size.height)), with: .color(.accent))
                }
            }

            let barHeight = size.height * 0.4
            let bar = CGRect(x: 0, y: (size.height - barHeight) / 2, width: x(value), height: barHeight)
            context.fill(Path(roundedRect: bar, cornerRadius: barHeight / 2), with: .color(barColor))
        }
    }
}

extension Macro {
    /// The macro's mark color. Marks only, never text, always next to the macro's word.
    var color: Color {
        switch self {
        case .protein: .protein
        case .fat: .fat
        case .carbs: .carbs
        }
    }
}

#Preview("Light") {
    RangeBandGallery().previewCard()
}

#Preview("Dark") {
    RangeBandGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    ScrollView { RangeBandGallery().previewCard() }
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct RangeBandGallery: View {
    var body: some View {
        VStack(spacing: Spacing.s5) {
            RangeBand(label: Macro.protein.name, value: 77, min: 110, max: 140, macro: .protein)
            // Outside the band: looks exactly like inside or below.
            RangeBand(label: Macro.fat.name, value: 86, min: 55, max: 80, macro: .fat)
            RangeBand(label: String(localized: "Calories"), value: 1200, min: 1900, max: 2200, unit: .kcal)
        }
        .cardStyle()
    }
}
