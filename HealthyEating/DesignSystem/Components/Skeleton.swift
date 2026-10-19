import SwiftUI

/// Placeholder blocks in `surface-sunken` while data loads. They keep the final layout, so
/// nothing jumps when the content arrives. Pulses gently only when Reduce Motion is off.
/// See design/system/components/Skeleton.
struct Skeleton: View {
    /// Number of text lines.
    var lines: Int = 3
    /// A taller first block, for a hero number.
    var block = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false
    @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 14
    @ScaledMetric(relativeTo: .largeTitle) private var blockHeight: CGFloat = 52

    /// Line widths as fractions of the card, repeating, so the placeholder reads as text.
    private static let widths: [CGFloat] = [0.72, 0.48, 0.86, 0.6, 0.4]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            if block {
                shape(width: 0.4, height: blockHeight, radius: Radius.md)
            }
            ForEach(0..<lines, id: \.self) { index in
                shape(width: Self.widths[index % Self.widths.count], height: lineHeight, radius: lineHeight / 2)
            }
        }
        .cardStyle(padding: Spacing.s5)
        .opacity(dimmed ? 0.55 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { dimmed = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Loading"))
    }

    private func shape(width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        Color.clear
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.surfaceSunken)
                        .frame(width: proxy.size.width * width, height: height)
                }
            }
    }
}

/// Screen-level loading: the cards of a data screen as skeletons (G1 loading).
struct LoadingCards: View {
    var body: some View {
        VStack(spacing: Spacing.s5) {
            Skeleton(lines: 6, block: true)
            Skeleton(lines: 3)
        }
    }
}

#Preview("Light") {
    ScrollView { LoadingCards().padding() }.background(Color.bg)
}

#Preview("Dark") {
    ScrollView { LoadingCards().padding() }.background(Color.bg).preferredColorScheme(.dark)
}

#Preview("AX5") {
    ScrollView { LoadingCards().padding() }.background(Color.bg)
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct SkeletonGallery: View {
    var body: some View {
        VStack(spacing: Spacing.s3) {
            Skeleton(lines: 2, block: true)
            Skeleton(lines: 3)
        }
    }
}
