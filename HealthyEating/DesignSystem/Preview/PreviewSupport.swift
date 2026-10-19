import SwiftUI

extension View {
    /// Wraps a component for previews and snapshot tests: screen margin on the `bg` background.
    func previewCard() -> some View {
        self
            .padding(Spacing.s4)
            .frame(maxWidth: .infinity)
            .background(Color.bg)
    }
}
