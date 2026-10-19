import SwiftUI

/// Loads what Today shows: today's meals, the day's totals, targets and integration status.
@MainActor
@Observable
final class TodayModel {
    struct Snapshot {
        var meals: [Meal]
        var day: DayTotals?
        var settings: UserSettings
        var integration: IntegrationState
    }

    private(set) var state: Loadable<Snapshot> = .loading
    /// A refresh failed while older data is on screen: shown as a calm banner.
    private(set) var refreshError: APIError?
    private(set) var isMarking = false

    func load(_ data: any NutritionDataSource, now: Date = .now) async -> APIError? {
        do {
            async let meals = data.meals(on: now)
            async let days = data.days(from: now, to: now)
            async let settings = data.settings()
            async let integration = data.integrationStatus()
            state = .loaded(Snapshot(
                meals: try await meals, day: try await days.days.first,
                settings: try await settings, integration: try await integration))
            refreshError = nil
            return nil
        } catch {
            let apiError = error as? APIError ?? .unexpectedResponse(String(describing: error))
            if state.value == nil {
                state = .failed(apiError)
            } else {
                refreshError = apiError
            }
            return apiError
        }
    }

    /// Marks today complete, or removes the mark.
    func setComplete(_ complete: Bool, _ data: any NutritionDataSource) async -> APIError? {
        isMarking = true
        defer { isMarking = false }
        do throws(APIError) {
            try await data.setMark(complete ? .complete : nil, on: .now)
        } catch {
            refreshError = error
            return error
        }
        return await load(data)
    }
}

/// B1 Today: the summary card against the target ranges, the integration status and today's
/// meals; B2 when nothing is logged; G1 while loading or when the server is unreachable.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @State private var model = TodayModel()

    var body: some View {
        NavigationStack {
            content
                .background(Color.bg)
                .navigationTitle("Today")
                .navigationDestination(for: Meal.self) { meal in
                    MealDetailView(meal: meal) { Task { await reload() } }
                }
        }
        .task { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    dateLine
                    LoadingCards()
                }
                .padding(.horizontal, Spacing.s4)
            }
        case .failed(let error):
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    dateLine
                    ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                        .padding(.top, Spacing.s8)
                }
                .padding(.horizontal, Spacing.s4)
            }
        case .loaded(let snapshot):
            loaded(snapshot)
        }
    }

    private var dateLine: some View {
        Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
            .font(.subheadline)
            .foregroundStyle(.inkMuted)
            .padding(.horizontal, Spacing.s1)
    }

    private func loaded(_ snapshot: TodayModel.Snapshot) -> some View {
        let isNewUser = snapshot.meals.isEmpty && snapshot.integration.lastMealSavedAt == nil
        return List {
            Section {
                dateLine.plainListRow()
                if let error = model.refreshError {
                    Banner(kind: .error, message: error.message, actionTitle: "Retry") { Task { await reload() } }
                        .plainListRow()
                }
                if isNewUser {
                    TodayConnectCard(server: app.server).plainListRow()
                    IntegrationStatus(state: .unknown, text: "No meals received yet")
                        .padding(.horizontal, Spacing.s1)
                        .plainListRow()
                } else {
                    summary(snapshot).plainListRow()
                    integrationLine(snapshot.integration)
                        .padding(.horizontal, Spacing.s1)
                        .plainListRow()
                    if snapshot.meals.isEmpty {
                        VStack(spacing: Spacing.s1) {
                            Text("No meals yet today")
                                .font(.headline)
                                .foregroundStyle(.ink)
                            Text("Meals you log in Claude or ChatGPT appear here.")
                                .foregroundStyle(.inkMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .cardStyle(padding: Spacing.s5)
                        .plainListRow()
                    }
                }
            }
            .listSectionSpacing(Spacing.s3)

            if !snapshot.meals.isEmpty {
                Section {
                    ForEach(snapshot.meals) { meal in
                        NavigationLink(value: meal) {
                            MealRow(meal: meal, hideKcal: app.calmMode)
                        }
                    }
                } header: {
                    Text("Meals").sectionTextStyle()
                }
                .listRowBackground(Color.surface)

                Section { markDay(snapshot.day).plainListRow() }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await reload() }
    }

    private func summary(_ snapshot: TodayModel.Snapshot) -> some View {
        DaySummaryCard(day: snapshot.day, settings: snapshot.settings, calm: app.calmMode)
    }

    private func integrationLine(_ integration: IntegrationState) -> some View {
        guard let savedAt = integration.lastMealSavedAt else {
            return IntegrationStatus(state: .unknown, text: "No meals received yet")
        }
        let when = RelativeTimeFormat.string(for: savedAt)
        let recent = Date.now.timeIntervalSince(savedAt) < 24 * 3600
        if let assistant = integration.lastAssistant {
            return IntegrationStatus(state: recent ? .ok : .quiet, text: "Last meal saved \(when) via \(assistant)")
        }
        return IntegrationStatus(state: recent ? .ok : .quiet, text: "Last meal saved \(when)")
    }

    private func markDay(_ day: DayTotals?) -> some View {
        let isComplete = day?.status == .complete
        return VStack(spacing: 2) {
            if isComplete {
                Label("Day marked as complete", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ink)
                Button("Undo") { Task { await setComplete(false) } }
                    .buttonStyle(.action(.plain))
            } else {
                Button("Mark day as complete", systemImage: "checkmark.circle") { Task { await setComplete(true) } }
                    .buttonStyle(.action(.plain))
                Text("Complete days count in your averages.")
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .disabled(model.isMarking)
        .frame(maxWidth: .infinity)
    }

    private func reload() async {
        guard let data = app.data else { return }
        if let error = await model.load(data) { app.handle(error) }
    }

    private func setComplete(_ complete: Bool) async {
        guard let data = app.data else { return }
        if let error = await model.setComplete(complete, data) { app.handle(error) }
    }
}

/// G1 server unreachable (and other load failures): calm, says the data is safe, offers Retry.
struct ServerErrorMessage: View {
    let error: APIError
    let host: String?
    let retry: () -> Void

    var body: some View {
        if case .unreachable(let detail) = error {
            StateMessage(
                systemImage: "server.rack",
                title: String(localized: "Can’t reach \(CopyField.breakable(host ?? String(localized: "your server")))"),
                message: String(localized: "Check that your server is running and that you are online. Your data is safe on your server."),
                primaryTitle: "Retry", primarySystemImage: "arrow.clockwise", primaryAction: retry,
                detail: String(localized: "Details: \(detail)"))
        } else {
            StateMessage(
                systemImage: "server.rack",
                title: String(localized: "Couldn’t load this"),
                message: error.message,
                primaryTitle: "Retry", primarySystemImage: "arrow.clockwise", primaryAction: retry,
                detail: error.detail.map { String(localized: "Details: \($0)") })
        }
    }
}

/// B2 empty state for a new user: how to connect the assistant, with the connection URL.
struct TodayConnectCard: View {
    let server: ServerAddress?
    @State private var showingSteps = false
    @State private var assistant: AssistantKind = .claude

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            SymbolTile(systemName: "bubble.left")
            Text("Connect your AI assistant")
                .font(.title3Semibold)
                .foregroundStyle(.ink)
            Text("Healthy Eating gets your meals from the chat you already use. Add this URL to Claude as a connector or to ChatGPT as a plugin.")
                .font(.callout)
                .foregroundStyle(.ink)
            if let server {
                CopyField(value: server.mcpURL.absoluteString)
            }
            Button("Show steps") { showingSteps = true }
                .buttonStyle(.action(.secondary))
        }
        .cardStyle(padding: Spacing.s5)
        .sheet(isPresented: $showingSteps) {
            NavigationStack {
                ScrollView {
                    ConnectionSteps(assistant: $assistant, mcpURL: server?.mcpURL).padding(Spacing.s5)
                }
                .background(Color.bg)
                .navigationTitle("Connection steps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingSteps = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

#Preview("Light") {
    TodayView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    TodayView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    TodayView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
