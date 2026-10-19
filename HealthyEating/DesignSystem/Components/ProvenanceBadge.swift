import SwiftUI

/// Says where a meal's numbers came from: "Your numbers" or "Estimated".
/// Always text plus a glyph; neither tone means better or worse. See design/system/components/ProvenanceBadge.
struct ProvenanceBadge: View {
    let kind: Provenance

    var body: some View {
        HStack(spacing: Spacing.s1) {
            Image(systemName: symbol)
                .imageScale(.small)
                .accessibilityHidden(true)
            title
        }
        .font(.caption1Medium)
        .foregroundStyle(kind == .user ? Color.accent : Color.inkMuted)
        .padding(.vertical, 2)
        .padding(.leading, 6)
        .padding(.trailing, 7)
        .background(kind == .user ? Color.accentSoft : Color.surfaceSunken,
                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch kind {
        case .user: "person.fill"
        case .estimated: "plusminus"
        }
    }

    private var title: Text {
        switch kind {
        case .user: Text("Your numbers")
        case .estimated: Text("Estimated")
        }
    }
}

#Preview("Light") {
    ProvenanceBadgeGallery().previewCard()
}

#Preview("Dark") {
    ProvenanceBadgeGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    ProvenanceBadgeGallery().previewCard().environment(\.dynamicTypeSize, .accessibility5)
}

struct ProvenanceBadgeGallery: View {
    var body: some View {
        FlowLayout {
            ProvenanceBadge(kind: .user)
            ProvenanceBadge(kind: .estimated)
        }
    }
}
