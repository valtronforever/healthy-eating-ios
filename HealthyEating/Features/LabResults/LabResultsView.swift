import SwiftUI

/// The person's lab reports, shared by the list and the screens it opens, so a deletion shows
/// everywhere at once.
@MainActor
@Observable
final class LabResultsModel {
    private(set) var state: Loadable<[LabReport]> = .loading

    var histories: [LabAnalyteHistory] { LabAnalyteHistory.histories(state.value ?? []) }

    func report(_ id: UUID) -> LabReport? { state.value?.first { $0.id == id } }
    func history(_ id: String) -> LabAnalyteHistory? { histories.first { $0.id == id } }

    /// Keeps what it shows when a reload fails.
    func load(_ data: any NutritionDataSource) async -> APIError? {
        do {
            state = .loaded(try await data.labReports())
            return nil
        } catch {
            if state.value == nil { state = .failed(error) }
            return error
        }
    }

    /// Deletes one result, or the whole report, and reloads. Already gone counts as deleted.
    func delete(result id: UUID, _ data: any NutritionDataSource) async -> APIError? {
        do {
            try await data.deleteLabResult(id)
        } catch .notFound {
        } catch {
            return error
        }
        return await load(data)
    }

    func delete(report id: UUID, _ data: any NutritionDataSource) async -> APIError? {
        do {
            try await data.deleteLabReport(id)
        } catch .notFound {
        } catch {
            return error
        }
        return await load(data)
    }
}

/// Lab results (ios#47, backend #37), opened from Trends: each analyte with its latest value
/// and date, then the reports. Values and ranges as printed, never colored or judged. Lab
/// results are saved from the chat only and stay out of widgets and Apple Health.
struct LabResultsView: View {
    @Environment(AppModel.self) private var app
    @State private var model = LabResultsModel()

    var body: some View {
        List {
            switch model.state {
            case .loading:
                LoadingCards().plainListRow()
            case .failed(let error):
                ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                    .padding(.top, Spacing.s6)
                    .plainListRow()
            case .loaded(let reports) where reports.isEmpty:
                StateMessage(
                    systemImage: "doc.text.magnifyingglass", title: String(localized: "No lab results yet"),
                    message: String(localized: "Share a photo of your lab report with your assistant to add results here."))
                    .padding(.top, Spacing.s6)
                    .plainListRow()
                    .accessibilityIdentifier("labResultsEmpty")
            case .loaded(let reports):
                analytesSection
                reportsSection(reports)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Lab results")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("labResultsList")
        .refreshable { await reload() }
        .task(id: app.foregrounds) { await reload() }
    }

    private func reload() async {
        guard let data = app.data else { return }
        if let error = await model.load(data) { app.handle(error) }
    }

    private var analytesSection: some View {
        Section {
            ForEach(model.histories) { history in
                NavigationLink {
                    LabAnalyteView(model: model, historyID: history.id)
                } label: {
                    LabValueRow(title: history.title, subtitle: LabFormat.day(history.latest.takenOn), value: LabFormat.value(history.latest.result))
                }
                .accessibilityIdentifier("labAnalyte.\(history.id)")
            }
        } header: {
            Text("Latest values").sectionTextStyle()
        } footer: {
            Text("Values and ranges as printed on your reports. Your assistant saves them when you share a report in the chat.")
                .sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    private func reportsSection(_ reports: [LabReport]) -> some View {
        Section {
            ForEach(reports) { report in
                NavigationLink {
                    LabReportView(model: model, reportID: report.id)
                } label: {
                    LabValueRow(title: LabFormat.day(report.takenOn), subtitle: nil, value: LabFormat.resultCount(report.results.count))
                }
                .accessibilityIdentifier("labReport.\(report.id.uuidString.lowercased())")
            }
        } header: {
            Text("Reports").sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }
}

/// A name with a muted line under it and a value on the right; stacked at accessibility sizes.
struct LabValueRow: View {
    let title: String
    let subtitle: String?
    let value: String
    var valueSubtitle: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
                titles
                Spacer(minLength: Spacing.s2)
                values(alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: Spacing.s1) {
                titles
                values(alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title).foregroundStyle(.ink)
            if let subtitle {
                Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.inkMuted)
            }
        }
    }

    private func values(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(verbatim: value)
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(.ink)
            if let valueSubtitle {
                Text(verbatim: valueSubtitle).font(.footnote).foregroundStyle(.inkMuted)
            }
        }
    }
}

#Preview("Light") {
    NavigationStack { LabResultsView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { LabResultsView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { LabResultsView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
