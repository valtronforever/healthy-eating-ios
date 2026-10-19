import SwiftUI

/// B1 Today: the summary card, the integration status and today's meals.
/// Uses sample data until the backend serves meals (`SampleData`).
struct TodayView: View {
    @Environment(AppModel.self) private var model
    var meals: [Meal] = SampleData.meals

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                        .padding(.horizontal, Spacing.s1)
                        .plainListRow()
                    if meals.isEmpty {
                        TodayConnectCard(server: model.server)
                            .plainListRow()
                        IntegrationStatus(state: .unknown, text: "No meals received yet")
                            .padding(.horizontal, Spacing.s1)
                            .plainListRow()
                    } else {
                        SummaryCard(kcal: SampleData.kcalSoFar, kcalTarget: SampleData.kcalTarget,
                                    macros: SampleData.macros, calm: model.calmMode,
                                    footer: model.calmMode ? "Logged 6 of the last 7 days." : nil)
                            .plainListRow()
                        IntegrationStatus(
                            state: .ok,
                            text: "Last meal saved \(RelativeTimeFormat.string(for: SampleData.lastSavedAt)) via \(SampleData.lastSavedVia)")
                            .padding(.horizontal, Spacing.s1)
                            .plainListRow()
                    }
                }
                .listSectionSpacing(Spacing.s3)

                if !meals.isEmpty {
                    Section {
                        ForEach(meals) { meal in
                            NavigationLink(value: meal) {
                                MealRow(meal: meal, hideKcal: model.calmMode)
                            }
                        }
                    } header: {
                        Text("Meals").sectionTextStyle()
                    }
                    .listRowBackground(Color.surface)

                    Section {
                        VStack(spacing: 2) {
                            Button("Mark day as complete", systemImage: "checkmark.circle") {}
                                .buttonStyle(.action(.plain))
                                .disabled(true)
                            Text("Complete days count in your averages.")
                                .font(.footnote)
                                .foregroundStyle(.inkMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .plainListRow()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Today")
            .navigationDestination(for: Meal.self) { meal in
                MealDetailView(meal: meal)
            }
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
            Text("Healthy Eating gets your meals from the chat you already use. Add this URL as a connector in Claude or ChatGPT.")
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
                    ConnectionSteps(assistant: $assistant).padding(Spacing.s5)
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

#Preview("Empty, new user") {
    TodayView(meals: []).environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}
