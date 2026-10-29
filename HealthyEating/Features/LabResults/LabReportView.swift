import SwiftUI

/// One lab report (ios#47): every value with its unit and the lab's range as printed, in the
/// report's order. Swipe to delete a result; "Delete report" deletes all of them.
struct LabReportView: View {
    let model: LabResultsModel
    let reportID: UUID

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var deleting = false

    private var report: LabReport? { model.report(reportID) }

    var body: some View {
        List {
            if let report {
                Section {
                    ForEach(report.results) { result in
                        LabValueRow(title: result.name, subtitle: LabFormat.range(result), value: LabFormat.value(result))
                            .swipeActions {
                                Button("Delete", role: .destructive) { Task { await delete(result: result.id) } }
                            }
                            .accessibilityIdentifier("labResult.\(result.name)")
                    }
                } header: {
                    Text(verbatim: LabFormat.resultCount(report.results.count)).sectionTextStyle()
                } footer: {
                    Text("Values, units and ranges as printed on the report.").sectionTextStyle()
                }
                .listRowBackground(Color.surface)

                Section {
                    Button("Delete report") { confirmingDelete = true }
                        .buttonStyle(.action(.destructive))
                        .disabled(deleting)
                        .plainListRow()
                        .accessibilityIdentifier("deleteLabReport")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle(Text(verbatim: report.map { LabFormat.day($0.takenOn) } ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("labReport")
        .confirmationDialog("Delete this lab report?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete report", role: .destructive) { Task { await deleteReport() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(verbatim: Self.deleteMessage(report))
        }
        .onChange(of: report == nil) { _, gone in
            if gone { dismiss() }
        }
    }

    /// "All 4 results from Oct 20, 2026 are deleted. This can’t be undone."
    nonisolated static func deleteMessage(_ report: LabReport?) -> String {
        guard let report else { return "" }
        let day = LabFormat.day(report.takenOn)
        let count = report.results.count
        return count == 1
            ? String(localized: "The result from \(day) is deleted. This can’t be undone.")
            : String(localized: "All \(count) results from \(day) are deleted. This can’t be undone.")
    }

    private func delete(result id: UUID) async {
        guard let data = app.data else { return }
        if let error = await model.delete(result: id, data) { app.handle(error) }
    }

    private func deleteReport() async {
        guard let data = app.data else { return }
        deleting = true
        defer { deleting = false }
        if let error = await model.delete(report: reportID, data) { app.handle(error) }
    }
}

#Preview("Light") {
    NavigationStack { LabReportPreview(model: LabResultsModel()) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { LabReportPreview(model: LabResultsModel()) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { LabReportPreview(model: LabResultsModel()) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}

/// Loads the sample reports and shows the newest one.
private struct LabReportPreview: View {
    let model: LabResultsModel
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if let report = model.state.value?.first {
                LabReportView(model: model, reportID: report.id)
            } else {
                ProgressView()
            }
        }
        .task {
            if let data = app.data { _ = await model.load(data) }
        }
    }
}
