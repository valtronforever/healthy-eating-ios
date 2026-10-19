import SwiftUI

/// Onboarding: A1 Welcome → A2 Server (Continue signs in: A3) → A4 Connect your AI assistant →
/// A5 Waiting for the first meal. Someone who connected their assistant first (the account
/// already has meals) goes straight to Today after signing in.
struct OnboardingFlow: View {
    enum Step: Hashable {
        case server
        case connect
        case waiting
    }

    @Environment(AppModel.self) private var model
    @State private var path: [Step] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append(.server) }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .server:
                        ServerView {
                            Task {
                                if await model.accountHasMeals() {
                                    model.completeOnboarding()
                                } else {
                                    path.append(.connect)
                                }
                            }
                        }
                    case .connect: ConnectAssistantView { path.append(.waiting) }
                    case .waiting: WaitingForMealView { path.removeLast() }
                    }
                }
        }
    }
}

/// Shared layout for onboarding screens: scrolling content and a pinned bottom action area.
/// At accessibility text sizes the footer scrolls with the content instead of staying pinned,
/// so it never covers most of the screen.
struct OnboardingScaffold<Content: View, Footer: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let inlineFooter = dynamicTypeSize.isAccessibilitySize
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s6) {
                content
                if inlineFooter {
                    footerStack
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if !inlineFooter {
                footerStack
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, Spacing.s3)
                    .padding(.bottom, Spacing.s2)
                    .background(Color.bg)
            }
        }
        .background(Color.bg)
    }

    private var footerStack: some View {
        VStack(spacing: Spacing.s1) {
            footer
        }
    }
}

#Preview("Light") {
    OnboardingFlow().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.resetOnboarding]))
}

#Preview("Dark") {
    OnboardingFlow().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.resetOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    OnboardingFlow().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.resetOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
