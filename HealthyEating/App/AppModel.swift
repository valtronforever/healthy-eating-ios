import Foundation
import Observation

/// App-wide state: the person's server, whether they are signed in, onboarding progress and
/// Calm mode. Injected through the environment. Tokens never live here: they are in the
/// Keychain (`CredentialStore`) and handed out by `AuthSession`.
@MainActor
@Observable
final class AppModel {
    private(set) var server: ServerAddress?
    private(set) var isSignedIn = false
    private(set) var hasCompletedOnboarding: Bool
    /// Set when the server ended the session; onboarding explains it.
    private(set) var sessionEndedMessage: String?
    /// Calm mode hides calories everywhere.
    var calmMode: Bool {
        didSet {
            defaults.set(calmMode, forKey: Keys.calmMode)
            // Also stored on the server, so it follows the person to another device.
            if let data, oldValue != calmMode {
                let calm = calmMode
                Task { _ = try? await data.updateSettings(.init(calmMode: calm)) }
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let credentials: CredentialStore
    @ObservationIgnored private let signInProvider: any SignInProviding
    @ObservationIgnored private(set) var authSession: AuthSession?
    /// Where the screens read and change data: the server, or sample data in UI tests.
    @ObservationIgnored private(set) var data: (any NutritionDataSource)?
    @ObservationIgnored private let usesSampleData: Bool

    private enum Keys {
        static let serverURL = "serverURL"
        static let onboardingComplete = "onboardingComplete"
        static let calmMode = "calmMode"
    }

    /// Launch arguments used by UI tests and screenshots.
    enum LaunchArgument {
        /// Start at Welcome with nothing stored.
        static let resetOnboarding = "-resetOnboarding"
        /// Start on the tabs, signed in to the example server, without network.
        static let skipOnboarding = "-skipOnboarding"
        /// Sign in without the web sheet or network (UI tests of onboarding).
        static let placeholderSignIn = "-placeholderSignIn"
        /// `-initialTab history` opens that tab first (screenshots).
        static let initialTab = "-initialTab"

        static func initialTab(in arguments: [String]) -> AppTab? {
            guard let index = arguments.firstIndex(of: initialTab), arguments.indices.contains(index + 1) else { return nil }
            return AppTab(rawValue: arguments[index + 1])
        }

        /// UI tests, screenshots and previews keep tokens in memory, never in the Keychain.
        static func usesPlaceholders(_ arguments: [String]) -> Bool {
            arguments.contains(skipOnboarding) || arguments.contains(placeholderSignIn)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        secureStore: (any SecureStore)? = nil,
        signInProvider: (any SignInProviding)? = nil
    ) {
        let placeholders = LaunchArgument.usesPlaceholders(arguments)
        let store = CredentialStore(store: secureStore ?? (placeholders ? MemoryStore() : Keychain()))
        self.defaults = defaults
        self.credentials = store
        self.signInProvider = signInProvider ?? (placeholders ? PlaceholderSignIn() : OAuthSignIn())
        self.usesSampleData = placeholders
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
        if let storedServer, arguments.contains(LaunchArgument.skipOnboarding) {
            store.save(Credentials(clientID: "placeholder", accessToken: "placeholder", refreshToken: nil, expiresAt: nil), for: storedServer)
        }
        let signedIn = storedServer.map(store.hasCredentials(for:)) ?? false
        server = storedServer
        calmMode = defaults.bool(forKey: Keys.calmMode)
        isSignedIn = signedIn
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingComplete) && signedIn
        if let storedServer, signedIn {
            startSession(for: storedServer)
        }
    }

    private func startSession(for server: ServerAddress) {
        let session = AuthSession(server: server, store: credentials)
        authSession = session
        data = usesSampleData ? SampleDataSource() : APIClient(server: server, auth: session)
    }

    /// Sends the device's time zone when the server has none yet, so local days match the
    /// person's days. A different stored time zone is kept (the person may have chosen it);
    /// Settings offers to switch.
    func syncTimeZoneIfNeeded(device: TimeZone = .current) async {
        guard let data else { return }
        do throws(APIError) {
            let settings = try await data.settings()
            if settings.timeZone == nil {
                _ = try await data.updateSettings(.init(timeZone: .some(device.identifier)))
            }
        } catch {
            handle(error)
        }
    }

    /// Call with every API error a screen gets: an ended session returns to onboarding.
    func handle(_ error: APIError) {
        if error == .sessionExpired { sessionEnded() }
    }

    func setServer(_ address: ServerAddress) {
        if address != server {
            isSignedIn = credentials.hasCredentials(for: address)
            authSession = nil
            data = nil
            if isSignedIn { startSession(for: address) }
        }
        server = address
        defaults.set(address.baseURL.absoluteString, forKey: Keys.serverURL)
    }

    /// Signs in to the current server through its login page (A3).
    func signIn() async throws(AuthError) {
        guard let server else { throw .notAHealthyEatingServer }
        _ = try await signInProvider.signIn(to: server, store: credentials)
        startSession(for: server)
        sessionEndedMessage = nil
        isSignedIn = true
    }

    func completeOnboarding() {
        guard server != nil, isSignedIn else { return }
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.onboardingComplete)
    }

    /// Revokes the session on the server, forgets the tokens and returns to Welcome.
    func signOut() async {
        await authSession?.signOut()
        reset()
    }

    /// The account is gone from the server: forget the tokens (nothing left to revoke).
    func accountDeleted() async {
        if let server { credentials.delete(for: server) }
        reset()
    }

    /// The server refused to refresh the session: back to onboarding with an explanation.
    func sessionEnded() {
        if let server { credentials.delete(for: server) }
        reset()
        sessionEndedMessage = AuthError.sessionExpired.message
    }

    private func reset() {
        authSession = nil
        data = nil
        isSignedIn = false
        server = nil
        hasCompletedOnboarding = false
        defaults.removeObject(forKey: Keys.serverURL)
        defaults.removeObject(forKey: Keys.onboardingComplete)
    }
}
