import SwiftUI

/// E3 Delete account: what is deleted, the offer to export first, and a typed confirmation.
/// Meals logged elsewhere (a ChatGPT project, a spreadsheet) are not touched.
struct DeleteAccountView: View {
    let host: String
    let assistants: Int
    var onExport: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    @State private var isDeleting = false
    @State private var error: APIError?

    private var confirmed: Bool { confirmation.trimmingCharacters(in: .whitespaces) == "DELETE" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("Delete your account?")
                            .font(.title2Bold)
                            .foregroundStyle(.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("This deletes your account and everything stored for it on \(CopyField.breakable(host)):")
                            .foregroundStyle(.ink)
                    }
                    VStack(spacing: 0) {
                        item("Meals", "All")
                        item("Day marks", "All")
                        item("Targets and settings", "All")
                        item("Connected assistants", "\(assistants)")
                    }
                    .cardStyle(padding: Spacing.s4)
                    Text("It can’t be undone. Meals you logged elsewhere, for example in a ChatGPT project or a spreadsheet, are not touched.")
                        .foregroundStyle(.inkMuted)
                    Button {
                        onExport()
                    } label: {
                        Label("Export data first", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.action(.secondary))

                    LabeledTextField(
                        label: "Type DELETE to confirm", text: $confirmation, placeholder: "DELETE",
                        error: error?.message, identifier: "deleteConfirmation", onSubmit: {})
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    Button {
                        Task { await delete() }
                    } label: {
                        if isDeleting { ProgressView() } else { Text("Delete account") }
                    }
                    .buttonStyle(.action(.destructive))
                    .disabled(!confirmed || isDeleting)
                    .accessibilityIdentifier("confirmDeleteAccount")
                }
                .padding(Spacing.s5)
            }
            .background(Color.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func item(_ title: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value).foregroundStyle(.inkMuted)
        } label: {
            Text(title).foregroundStyle(.ink)
        }
        .padding(.vertical, Spacing.s2)
    }

    private func delete() async {
        guard let data = app.data else { return }
        isDeleting = true
        defer { isDeleting = false }
        do throws(APIError) {
            try await data.deleteAccount()
            dismiss()
            await app.accountDeleted()
        } catch {
            self.error = error
            app.handle(error)
        }
    }
}
