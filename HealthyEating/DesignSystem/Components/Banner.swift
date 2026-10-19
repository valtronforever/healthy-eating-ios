import SwiftUI

/// A calm inline message at the top of a screen's content. No red and no warning triangle, even
/// for errors: state the fact, reassure about the data, offer one action.
/// See design/system/components/Banner.
struct Banner: View {
    enum Kind {
        /// Offline with cached data: `surface-sunken`.
        case stale
        /// Server unreachable: `surface` with a `line` outline.
        case error
        /// A neutral note: `accent-soft`.
        case info
    }

    let kind: Kind
    var title: LocalizedStringKey?
    var text: LocalizedStringKey?
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Image(systemName: symbol)
                .imageScale(.medium)
                .foregroundStyle(kind == .info ? Color.accent : Color.ink)
                .padding(.top, 1)
                .accessibilityHidden(true)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s2))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.s3))
            layout {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title).fontWeight(.semibold).foregroundStyle(.ink)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let text {
                        Text(text).foregroundStyle(.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accent)
                        .buttonStyle(.plain)
                        .frame(minHeight: Spacing.tapTarget)
                }
            }
        }
        .font(.subheadline)
        .padding(.vertical, Spacing.s3)
        .padding(.horizontal, Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            if kind == .error {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Color.line, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var symbol: String {
        switch kind {
        case .stale: "wifi.slash"
        case .error: "server.rack"
        case .info: "info.circle"
        }
    }

    private var background: Color {
        switch kind {
        case .stale: .surfaceSunken
        case .error: .surface
        case .info: .accentSoft
        }
    }
}

#Preview("Light") {
    BannerGallery().previewCard()
}

#Preview("Dark") {
    BannerGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    ScrollView { BannerGallery().previewCard() }
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct BannerGallery: View {
    var body: some View {
        VStack(spacing: Spacing.s3) {
            Banner(kind: .stale, title: "Offline", text: "Showing data from 09:42. It updates when you are back online.")
            Banner(kind: .error, title: "Can’t reach food.example.com",
                   text: "Your data is safe on your server.", actionTitle: "Retry", action: {})
            Banner(kind: .info, text: "Averages use complete days only.")
        }
    }
}
