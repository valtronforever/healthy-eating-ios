import SwiftUI
import UIKit

/// A read-only URL in monospace with a Copy button that confirms in place ("Copied", then back).
/// The value wraps rather than truncates. See design/system/components/CopyField.
struct CopyField: View {
    var label: LocalizedStringKey?
    let value: String
    /// The Copy button's title, for example "Copy" or "Copy message".
    var buttonTitle: LocalizedStringKey = "Copy"
    /// URLs use `code` (SF Mono); `false` shows a sentence, such as a sample message, in `body`.
    var isCode = true

    @State private var copied = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
            }
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s2))
                : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.s2))
            layout {
                Text(verbatim: isCode ? Self.breakable(value) : value)
                    .font(isCode ? .code : .body)
                    .foregroundStyle(.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: value))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.s2)
                Button(action: copy) {
                    Label {
                        copied ? Text("Copied") : Text(buttonTitle)
                    } icon: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accent)
                    .padding(.horizontal, Spacing.s3)
                    .frame(minHeight: Spacing.tapTarget)
                    .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, Spacing.s3)
            .padding([.top, .bottom, .trailing], Spacing.s1)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
        }
    }

    /// Lets long URLs wrap after "/" and "." instead of being hyphenated, which would change
    /// the address as read. Display only: the Copy button always copies `value` unchanged.
    static func breakable(_ url: String) -> String {
        url.replacingOccurrences(of: "/", with: "/\u{200B}")
            .replacingOccurrences(of: ".", with: ".\u{200B}")
    }

    private func copy() {
        UIPasteboard.general.string = value
        copied = true
        AccessibilityNotification.Announcement(String(localized: "Copied")).post()
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
        }
    }
}

#Preview("Light") {
    CopyFieldGallery().previewCard()
}

#Preview("Dark") {
    CopyFieldGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    CopyFieldGallery().previewCard().environment(\.dynamicTypeSize, .accessibility5)
}

struct CopyFieldGallery: View {
    var body: some View {
        CopyField(label: "Connection URL", value: "\(SampleData.exampleServer)/mcp")
    }
}
