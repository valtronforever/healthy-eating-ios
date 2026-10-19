import SwiftUI

/// Type tokens from design/system/tokens.json. Every style is a Dynamic Type text style, so
/// text scales up to AX5; never use fixed point sizes for text.
extension Font {
    /// `large-title`: navigation large titles (the system applies it to `.navigationTitle`).
    static let largeTitleBold = Font.largeTitle.bold()
    /// `title-2`: onboarding headings, sheet titles.
    static let title2Bold = Font.title2.bold()
    /// `title-3`: card and section headings.
    static let title3Semibold = Font.title3.weight(.semibold)
    /// `caption-1`: badges, chart labels, calendar legend.
    static let caption1Medium = Font.caption.weight(.medium)
    /// `code`: server and MCP URLs (SF Mono).
    static let code = Font.subheadline.monospaced()
}

/// Number styles: SF Pro Rounded with monospaced digits, scaled with Dynamic Type.
enum MetricSize {
    /// `metric-xl`: the one hero number on a screen.
    case xl
    /// `metric`: averages on Trends, widget figures.
    case regular
    /// `metric-sm`: kcal and grams in rows and macro lines.
    case small
}

private struct MetricFont: ViewModifier {
    let size: MetricSize
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 44

    func body(content: Content) -> some View {
        content
            .font(font)
            .fontDesign(.rounded)
            .monospacedDigit()
    }

    private var font: Font {
        switch size {
        case .xl: .system(size: heroSize, weight: .semibold, design: .rounded)
        case .regular: .title.weight(.semibold)
        case .small: .headline
        }
    }
}

extension View {
    /// Applies a number style (`metric-xl`, `metric` or `metric-sm`).
    func metricFont(_ size: MetricSize = .regular) -> some View {
        modifier(MetricFont(size: size))
    }
}
