import SwiftUI
import UniformTypeIdentifiers

/// Imports a Healthy Eating export (backend #27): the person picks the JSON or ZIP file, the
/// server checks it and says what it would add (a preview), and only then imports it.
@MainActor
@Observable
final class ImportDataModel {
    enum State: Equatable {
        case idle
        case checking
        case preview(ImportSummary)
        case importing(ImportSummary)
        case done(ImportSummary)
    }

    /// The server takes files up to 50 MB.
    static let maxBytes = 50 * 1024 * 1024

    private(set) var state: State = .idle
    private(set) var error: APIError?
    private var file: (data: Data, isZip: Bool)?

    /// Checks a chosen file with the server, without storing anything.
    func check(_ data: Data, using source: any NutritionDataSource) async -> APIError? {
        guard data.count <= Self.maxBytes else {
            return fail(.invalid(message: String(localized: "The file is larger than 50 MB."), fields: [:]))
        }
        // A ZIP starts with "PK"; anything else goes as JSON and the server says if it isn't.
        let isZip = data.starts(with: [0x50, 0x4B])
        file = (data, isZip)
        state = .checking
        error = nil
        do throws(APIError) {
            state = .preview(try await source.importData(data, isZip: isZip, preview: true))
            return nil
        } catch {
            file = nil
            state = .idle
            return fail(error)
        }
    }

    /// Imports the checked file. Returns true when it added something.
    func importFile(using source: any NutritionDataSource) async -> Bool {
        guard case .preview(let preview) = state, let file else { return false }
        state = .importing(preview)
        error = nil
        do throws(APIError) {
            let result = try await source.importData(file.data, isZip: file.isZip, preview: false)
            self.file = nil
            state = .done(result)
            return !result.addsNothing
        } catch {
            state = .preview(preview)
            _ = fail(error)
            return false
        }
    }

    func readFailed() {
        _ = fail(.invalid(message: String(localized: "The file could not be read."), fields: [:]))
    }

    private func fail(_ error: APIError) -> APIError {
        self.error = error
        return error
    }
}

struct ImportDataView: View {
    @Environment(AppModel.self) private var app
    @State private var model = ImportDataModel()
    @State private var choosing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                if let error = model.error {
                    Banner(kind: .error, message: error.message)
                }
                Text("Add the history from a Healthy Eating export, from this server or another one. Choose its JSON or ZIP file.")
                    .foregroundStyle(.ink)
                content
            }
            .padding(Spacing.s5)
        }
        .background(Color.bg)
        .navigationTitle("Import data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.json, .zip]) { result in
            guard case .success(let url) = result else { return }
            Task { await check(url) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            note
            chooseButton(primary: true)
        case .checking:
            HStack(spacing: Spacing.s3) {
                ProgressView()
                Text("Checking the file").foregroundStyle(.inkMuted)
            }
            .accessibilityElement(children: .combine)
        case .preview(let summary):
            summaryCard(summary)
            if summary.addsNothing {
                Text("Everything in this file is already here.").foregroundStyle(.inkMuted)
                chooseButton(primary: true)
            } else {
                note
                Button("Import") { Task { await importFile() } }
                    .buttonStyle(.action(.primary))
                    .accessibilityIdentifier("confirmImport")
                chooseButton(primary: false)
            }
        case .importing(let summary):
            summaryCard(summary)
            Button {} label: { ProgressView() }
                .buttonStyle(.action(.primary))
                .disabled(true)
        case .done(let summary):
            Text(ImportFormat.result(summary))
                .font(.headline)
                .foregroundStyle(.ink)
                .accessibilityIdentifier("importResult")
            summaryCard(summary)
            chooseButton(primary: false)
        }
    }

    private var note: some View {
        Text("Meals, weigh-ins and day marks are added. Anything already here is skipped, so importing a file twice adds nothing. Your account and settings stay as they are.")
            .font(.subheadline)
            .foregroundStyle(.inkMuted)
    }

    private func chooseButton(primary: Bool) -> some View {
        Button(primary ? "Choose file" : "Choose another file") { choosing = true }
            .buttonStyle(.action(primary ? .primary : .secondary))
            .accessibilityIdentifier("chooseImportFile")
    }

    private func summaryCard(_ summary: ImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Meals", ImportFormat.counts(new: summary.newMeals, known: summary.knownMeals))
            row("Weigh-ins", ImportFormat.counts(new: summary.newWeights, known: summary.knownWeights))
            if let days = ImportFormat.days(summary) {
                row("Days", days)
            }
            if let exported = summary.exportedAt {
                row("Exported", exported.formatted(date: .abbreviated, time: .omitted))
            }
            if summary.rejectedCount > 0 {
                row("Left out", ImportFormat.leftOut(summary.rejectedCount))
                ForEach(Array(summary.rejected.enumerated()), id: \.offset) { _, entry in
                    Text(ImportFormat.rejected(entry))
                        .font(.footnote)
                        .foregroundStyle(.inkMuted)
                        .padding(.vertical, Spacing.s1)
                }
            }
        }
        .cardStyle(padding: Spacing.s4)
        .accessibilityIdentifier("importSummary")
    }

    private func row(_ title: LocalizedStringKey, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(.ink)
                Spacer(minLength: Spacing.s3)
                Text(verbatim: value).foregroundStyle(.inkMuted).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text(title).foregroundStyle(.ink)
                Text(verbatim: value).foregroundStyle(.inkMuted)
            }
        }
        .padding(.vertical, Spacing.s2)
        .accessibilityElement(children: .combine)
    }

    private func check(_ url: URL) async {
        guard let data = app.data else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let contents = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            model.readFailed()
            return
        }
        if let error = await model.check(contents, using: data) { app.handle(error) }
    }

    private func importFile() async {
        guard let data = app.data else { return }
        if await model.importFile(using: data) {
            app.historyChanged()
        } else if let error = model.error {
            app.handle(error)
        }
    }
}

/// The wording of an import's preview and result.
nonisolated enum ImportFormat {
    static func counts(new: Int, known: Int) -> String {
        let added = String(localized: "\(new) new")
        guard known > 0 else { return added }
        return String(localized: "\(added), \(known) already here")
    }

    static func days(_ summary: ImportSummary) -> String? {
        guard let first = summary.firstDay, let last = summary.lastDay else { return nil }
        if first == last { return first.formatted(date: .abbreviated, time: .omitted) }
        return (first..<last).formatted(.interval.day().month(.abbreviated).year())
    }

    static func leftOut(_ count: Int) -> String {
        count.formatted()
    }

    static func rejected(_ entry: ImportSummary.Rejected) -> String {
        switch entry.kind {
        case .meal: String(localized: "Meal \(entry.position): \(entry.reason)")
        case .weight: String(localized: "Weigh-in \(entry.position): \(entry.reason)")
        }
    }

    static func result(_ summary: ImportSummary) -> String {
        // The counts are in the card under it, so no plural forms are needed here.
        summary.addsNothing ? String(localized: "Nothing new was imported.") : String(localized: "Import finished.")
    }
}

#Preview("Light") {
    NavigationStack { ImportDataView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { ImportDataView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { ImportDataView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
