import SwiftUI

/// A labeled single-line input (the design system's TextField): `line-strong` border at rest,
/// 2 pt `accent` when focused. Errors use a 2 pt `ink` border, an icon and a short sentence in
/// `ink`: never red. See design/system/components/TextField.
struct LabeledTextField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var placeholder: String = ""
    var hint: LocalizedStringKey?
    var error: String?
    /// SF Mono and URL keyboard settings, for server addresses.
    var isURL = false
    /// Stable identifier for UI tests.
    var identifier: String?
    var onSubmit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.inkMuted)
            field
                .font(isURL ? .code : .body)
                .foregroundStyle(.ink)
                .focused($focused)
                .accessibilityIdentifier(identifier ?? "")
                .onSubmit(onSubmit)
                .padding(.horizontal, Spacing.s3)
                .frame(minHeight: Spacing.tapTarget + 4)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: error != nil || focused ? 2 : 1))
            if let error {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s1 + 2) {
                    Image(systemName: "exclamationmark.circle")
                        .accessibilityHidden(true)
                    Text(verbatim: error)
                }
                .font(.footnote)
                .foregroundStyle(.ink)
                .accessibilityElement(children: .combine)
            } else if let hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
            }
        }
        .onChange(of: error) { _, newValue in
            if let newValue {
                AccessibilityNotification.Announcement(newValue).post()
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        let prompt = Text(verbatim: placeholder).foregroundStyle(Color.inkMuted)
        if isURL {
            TextField(text: $text, prompt: prompt) { Text(label) }
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.go)
        } else {
            TextField(text: $text, prompt: prompt) { Text(label) }
        }
    }

    private var borderColor: Color {
        if error != nil { return .ink }
        return focused ? .accent : .lineStrong
    }
}

#Preview("Light") {
    LabeledTextFieldGallery().previewCard()
}

#Preview("Dark") {
    LabeledTextFieldGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    LabeledTextFieldGallery().previewCard().environment(\.dynamicTypeSize, .accessibility5)
}

private struct LabeledTextFieldGallery: View {
    @State private var empty = ""
    @State private var insecure = "http://food.example.com"

    var body: some View {
        VStack(spacing: Spacing.s5) {
            LabeledTextField(label: "Server address", text: $empty, placeholder: "https://food.example.com",
                             hint: "Ask whoever runs your server if you are not sure.", isURL: true)
            LabeledTextField(label: "Server address", text: $insecure, error: ServerAddress.ValidationError.notHTTPS.message, isURL: true)
        }
    }
}
