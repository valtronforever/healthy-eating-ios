import SwiftUI

/// The design system's Button roles. One primary per screen.
enum ActionButtonVariant {
    /// `accent` fill, `on-accent` label: the single forward action.
    case primary
    /// `accent-soft` fill, `accent` label: helpful but optional.
    case secondary
    /// `accent` text only: quiet actions inside content.
    case plain
    /// `destructive` label on `surface-sunken`: irreversible actions, always followed by a confirmation.
    case destructive
}

struct ActionButtonStyle: ButtonStyle {
    var variant: ActionButtonVariant
    /// Full width (`block` in the design system).
    var block = true

    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(configuration: configuration, variant: variant, block: block)
    }
}

private struct ActionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let variant: ActionButtonVariant
    let block: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, variant == .plain ? Spacing.s2 : Spacing.s4)
            .padding(.vertical, variant == .plain ? Spacing.s2 : Spacing.s3)
            .frame(maxWidth: block && variant != .plain ? .infinity : nil, minHeight: variant == .plain ? Spacing.tapTarget : 50)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    private var foreground: Color {
        guard isEnabled else { return .inkMuted }
        switch variant {
        case .primary: return .onAccent
        case .secondary, .plain: return .accent
        case .destructive: return .destructive
        }
    }

    private var background: Color {
        switch variant {
        case .primary: isEnabled ? .accent : .surfaceSunken
        case .secondary: isEnabled ? .accentSoft : .surfaceSunken
        case .plain: .clear
        case .destructive: .surfaceSunken
        }
    }
}

extension ButtonStyle where Self == ActionButtonStyle {
    static func action(_ variant: ActionButtonVariant, block: Bool = true) -> ActionButtonStyle {
        ActionButtonStyle(variant: variant, block: block)
    }
}

#Preview("Light") {
    ActionButtonGallery().previewCard()
}

#Preview("Dark") {
    ActionButtonGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    ActionButtonGallery().previewCard().environment(\.dynamicTypeSize, .accessibility5)
}

private struct ActionButtonGallery: View {
    var body: some View {
        VStack(spacing: Spacing.s3) {
            Button("Get started") {}.buttonStyle(.action(.primary))
            Button("Continue") {}.buttonStyle(.action(.primary)).disabled(true)
            Button("Copy connection URL", systemImage: "doc.on.doc") {}.buttonStyle(.action(.secondary))
            Button("Mark day as complete", systemImage: "checkmark.circle") {}.buttonStyle(.action(.plain))
            Button("Delete account", role: .destructive) {}.buttonStyle(.action(.destructive))
        }
    }
}
