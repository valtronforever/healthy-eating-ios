import Foundation
import Observation

/// App-wide state: the person's server and onboarding progress. Injected through the environment.
/// Sign-in (OAuth + Keychain) is not built yet; see APP_STATE.md.
@Observable
final class AppModel {
    private(set) var server: ServerAddress?
    private(set) var hasCompletedOnboarding: Bool
    /// Calm mode hides calories everywhere.
    var calmMode: Bool {
        didSet { defaults.set(calmMode, forKey: Keys.calmMode) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let serverURL = "serverURL"
        static let onboardingComplete = "onboardingComplete"
        static let calmMode = "calmMode"
    }

    /// Launch arguments used by UI tests and screenshots.
    enum LaunchArgument {
        /// Start at Welcome with nothing stored.
        static let resetOnboarding = "-resetOnboarding"
        /// Start on the tabs with the example server.
        static let skipOnboarding = "-skipOnboarding"
        /// `-initialTab history` opens that tab first (screenshots).
        static let initialTab = "-initialTab"

        static func initialTab(in arguments: [String]) -> AppTab? {
            guard let index = arguments.firstIndex(of: initialTab), arguments.indices.contains(index + 1) else { return nil }
            return AppTab(rawValue: arguments[index + 1])
        }
    }

    init(defaults: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.defaults = defaults
        if arguments.contains(LaunchArgument.resetOnboarding) {
            for key in [Keys.serverURL, Keys.onboardingComplete, Keys.calmMode] {
                defaults.removeObject(forKey: key)
            }
        }
        if arguments.contains(LaunchArgument.skipOnboarding) {
            defaults.set(SampleData.exampleServer, forKey: Keys.serverURL)
            defaults.set(true, forKey: Keys.onboardingComplete)
        }
        let storedServer = defaults.string(forKey: Keys.serverURL).flatMap { try? ServerAddress.parse($0) }
        server = storedServer
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingComplete) && storedServer != nil
        calmMode = defaults.bool(forKey: Keys.calmMode)
    }

    func setServer(_ address: ServerAddress) {
        server = address
        defaults.set(address.baseURL.absoluteString, forKey: Keys.serverURL)
    }

    func completeOnboarding() {
        guard server != nil else { return }
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.onboardingComplete)
    }

    /// Returns to Welcome. Token revocation is added with sign-in.
    func signOut() {
        server = nil
        hasCompletedOnboarding = false
        defaults.removeObject(forKey: Keys.serverURL)
        defaults.removeObject(forKey: Keys.onboardingComplete)
    }
}
