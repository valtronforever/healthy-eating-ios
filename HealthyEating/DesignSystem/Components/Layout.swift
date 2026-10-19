import SwiftUI

extension View {
    /// A card: `surface` fill on `bg`, `radius-lg` continuous corners, `space-4` padding. Flat, no shadow.
    func cardStyle(padding: CGFloat = Spacing.s4) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    /// Section header and footer text in `ink-muted`; the system's secondary gray does not reach
    /// 4.5:1 on the `bg` background.
    func sectionTextStyle() -> some View {
        foregroundStyle(Color.inkMuted)
    }

    /// A list row that shows custom content (a card, a status line) on the screen background.
    func plainListRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
    }
}

/// An SF Symbol in a small rounded tile, used before feature lines and settings rows.
struct SymbolTile: View {
    let systemName: String
    var small = false
    @ScaledMetric(relativeTo: .body) private var regularSide: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var smallSide: CGFloat = 30

    var body: some View {
        Image(systemName: systemName)
            .imageScale(.medium)
            .font(small ? .subheadline : .body)
            .foregroundStyle(.accent)
            .frame(width: small ? smallSide : regularSide, height: small ? smallSide : regularSide)
            .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: small ? Radius.sm + 2 : Radius.md, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Lays out children left to right and wraps them onto new lines, so badges and legends
/// never truncate at large text sizes.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = Spacing.s2
    var verticalSpacing: CGFloat = Spacing.s1 + 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + verticalSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            let needed = current.indices.isEmpty ? size.width : current.width + horizontalSpacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? min(size.width, maxWidth) : current.width + horizontalSpacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
