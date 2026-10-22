import SwiftUI

/// A5 Waiting for your first meal: checks the integration status every few seconds until a
/// meal reaches the server, then shows it ("First meal received") so the person knows the
/// connection works.
struct WaitingForMealView: View {
    /// "Show connection steps": back to A4.
    var onShowSteps: () -> Void = {}

    @Environment(AppModel.self) private var app
    @State private var received: (meal: Meal?, assistant: String?)?
    @State private var lastError: APIError?
    @ScaledMetric(relativeTo: .largeTitle) private var circle: CGFloat = 104

    static let pollInterval: Duration = .seconds(3)

    var body: some View {
        OnboardingScaffold {
            if let received {
                receivedContent(received)
            } else {
                waitingContent
            }
        } footer: {
            if received != nil {
                Button("Go to Today") { app.completeOnboarding() }
                    .buttonStyle(.action(.primary))
            } else {
                Button("Show connection steps", action: onShowSteps)
                    .buttonStyle(.action(.plain))
                Button("Skip for now") { app.completeOnboarding() }
                    .buttonStyle(.action(.plain))
            }
        }
        .navigationBarBackButtonHidden(received != nil)
        .task { await poll() }
    }

    private var waitingContent: some View {
        VStack(spacing: Spacing.s4) {
            Image(systemName: "bubble.left")
                .font(.largeTitle)
                .foregroundStyle(.accent)
                .frame(width: circle, height: circle)
                .background(Color.accentSoft, in: Circle())
                .padding(.top, Spacing.s8)
                .accessibilityHidden(true)
            Text("Waiting for your first meal")
                .font(.title2Bold)
                .foregroundStyle(.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Send a meal to your assistant. It appears here a few seconds after the assistant saves it.")
                .foregroundStyle(.inkMuted)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("For example").font(.footnote).foregroundStyle(.inkMuted)
                Text("“Log my breakfast: oatmeal with berries”").font(.headline).foregroundStyle(.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.s4)
            .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            HStack(spacing: Spacing.s2) {
                Circle().fill(Color.chartFaded).frame(width: 8, height: 8).accessibilityHidden(true)
                Text(statusLine).font(.subheadline).foregroundStyle(.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusLine: String {
        if let lastError {
            return lastError.message
        }
        return String(localized: "Checking \(CopyField.breakable(app.server?.host ?? ""))…")
    }

    private func receivedContent(_ received: (meal: Meal?, assistant: String?)) -> some View {
        VStack(spacing: Spacing.s4) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.accent)
                .frame(width: circle, height: circle)
                .background(Color.accentSoft, in: Circle())
                .padding(.top, Spacing.s8)
                .accessibilityHidden(true)
            Group {
                if let assistant = received.assistant {
                    Text("First meal received from \(assistant)")
                } else {
                    Text("First meal received")
                }
            }
            .font(.title2Bold)
            .foregroundStyle(.ink)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            if let meal = received.meal {
                MealRow(meal: meal, hideKcal: app.calmMode)
                    .padding(Spacing.s4)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            Text("The connection works. Keep logging in your chat the way you do now.")
                .foregroundStyle(.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func poll() async {
        guard let data = app.data else { return }
        while !Task.isCancelled, received == nil {
            do throws(APIError) {
                let status = try await data.integrationStatus()
                lastError = nil
                if status.lastMealSavedAt != nil {
                    let meal = (try? await data.meals(on: .now))?.first
                    withAnimation { received = (meal, status.lastAssistant ?? meal?.assistant) }
                    return
                }
            } catch {
                lastError = error
                app.handle(error)
            }
            try? await Task.sleep(for: Self.pollInterval)
        }
    }
}

#Preview("Light") {
    NavigationStack { WaitingForMealView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.placeholderSignIn]))
}

#Preview("Dark") {
    NavigationStack { WaitingForMealView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.placeholderSignIn]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { WaitingForMealView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.placeholderSignIn]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
