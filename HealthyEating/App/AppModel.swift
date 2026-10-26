import Foundation
import Observation
import WidgetKit

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
            if oldValue != calmMode { WidgetUpdates.setCalmMode(calmMode) }
            // Also stored on the server, so it follows the person to another device.
            if let data, oldValue != calmMode, !adoptingServerSettings {
                let calm = calmMode
                Task { _ = try? await data.updateSettings(.init(calmMode: calm)) }
            }
        }
    }

    /// The opt-in notice when meals stop arriving (`ArrivalNotice`); off by default.
    private(set) var arrivalNoticeEnabled: Bool
    /// The person declined notifications when turning the notice on.
    private(set) var arrivalNoticeDeclined = false

    /// Set while screens show answers kept on the device because the server can't be reached:
    /// when the oldest of them was saved (the G1 offline banner). Cleared by the next answer.
    private(set) var offlineSince: Date?
    /// Counts the times the app came back to the foreground; screens reload on it.
    private(set) var foregrounds = 0

    /// Two-way sync of body weight with Apple Health (ios#32); off by default, per device.
    private(set) var appleHealthSyncEnabled: Bool
    /// When the last sync changed something, and how many changes (the switch shows it).
    private(set) var appleHealthLastSync: Date?
    private(set) var appleHealthLastSyncCount = 0

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let noticeCenter: any ArrivalNoticeCenter
    @ObservationIgnored private let appleHealth: any AppleHealthStore
    @ObservationIgnored private let healthSync: AppleHealthSync
    @ObservationIgnored private var syncingAppleHealth = false
    /// Set while a value read from the server is applied, so it is not sent back.
    @ObservationIgnored private var adoptingServerSettings = false
    @ObservationIgnored let credentials: CredentialStore
    @ObservationIgnored private let signInProvider: any SignInProviding
    /// The web sheet for adding a login (`LoginLinking`); a placeholder in UI tests.
    @ObservationIgnored let webAuthenticator: any WebAuthenticating
    @ObservationIgnored private(set) var authSession: AuthSession?
    /// Where the screens read and change data: the server, or sample data in UI tests.
    @ObservationIgnored private(set) var data: (any NutritionDataSource)?
    /// The offline copy of the signed-in server's answers (ios#20).
    @ObservationIgnored private var cache: ResponseCache?
    @ObservationIgnored private let usesSampleData: Bool
    /// `-skipOnboarding` shows a filled account; `-placeholderSignIn` a new one whose first meal
    /// arrives while A5 waits.
    @ObservationIgnored private let skipsOnboarding: Bool

    private enum Keys {
        static let serverURL = "serverURL"
        static let onboardingComplete = "onboardingComplete"
        static let calmMode = "calmMode"
        static let arrivalNotice = "arrivalNotice"
        /// `lastMealSavedAt` of the quiet spell the notice was posted for.
        static let arrivalNoticeNotifiedFor = "arrivalNoticeNotifiedFor"
        static let appleHealthSync = "appleHealthSync"
        static let appleHealthLastSync = "appleHealthLastSync"
        static let appleHealthLastSyncCount = "appleHealthLastSyncCount"

        static let appleHealth = [appleHealthSync, appleHealthLastSync, appleHealthLastSyncCount] + AppleHealthSync.keys
    }


    /// Launch arguments used by UI tests and screenshots.
    enum LaunchArgument {
        /// Start at Welcome with nothing stored (preferences and Keychain).
        static let resetOnboarding = "-resetOnboarding"
        /// Start on the tabs, signed in to the example server, without network.
        static let skipOnboarding = "-skipOnboarding"
        /// Sign in without the web sheet or network (UI tests of onboarding).
        static let placeholderSignIn = "-placeholderSignIn"
        /// `-initialTab history` opens that tab first (screenshots).
        static let initialTab = "-initialTab"
        /// With placeholders: show the G1 offline banner as if answers were kept since 09:42.
        static let showOffline = "-showOffline"

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
        signInProvider: (any SignInProviding)? = nil,
        webAuthenticator: (any WebAuthenticating)? = nil,
        noticeCenter: (any ArrivalNoticeCenter)? = nil,
        appleHealth: (any AppleHealthStore)? = nil
    ) {
        let placeholders = LaunchArgument.usesPlaceholders(arguments)
        let store = CredentialStore(store: secureStore ?? (placeholders ? MemoryStore() : Keychain()))
        self.defaults = defaults
        self.credentials = store
        self.signInProvider = signInProvider ?? (placeholders ? PlaceholderSignIn() : OAuthSignIn())
        self.webAuthenticator = webAuthenticator ?? (placeholders ? PlaceholderWebAuthenticator() : SystemWebAuthenticator())
        self.noticeCenter = noticeCenter ?? (placeholders ? PlaceholderArrivalNoticeCenter() : SystemArrivalNoticeCenter())
        let health = appleHealth ?? (placeholders ? PlaceholderAppleHealthStore() : SystemAppleHealthStore())
        self.appleHealth = health
        self.healthSync = AppleHealthSync(health: health, defaults: defaults)
        self.usesSampleData = placeholders
        self.skipsOnboarding = arguments.contains(LaunchArgument.skipOnboarding)
        if arguments.contains(LaunchArgument.resetOnboarding) {
            for key in [Keys.serverURL, Keys.onboardingComplete, Keys.calmMode, Keys.arrivalNotice, Keys.arrivalNoticeNotifiedFor] + Keys.appleHealth {
                defaults.removeObject(forKey: key)
            }
            // A clean start: no session from an earlier run (the Keychain outlives the app).
            store.store.deleteAll()
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
        arrivalNoticeEnabled = defaults.bool(forKey: Keys.arrivalNotice)
        appleHealthSyncEnabled = defaults.bool(forKey: Keys.appleHealthSync)
        appleHealthLastSync = defaults.object(forKey: Keys.appleHealthLastSync) as? Date
        appleHealthLastSyncCount = defaults.integer(forKey: Keys.appleHealthLastSyncCount)
        isSignedIn = signedIn
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingComplete) && signedIn
        if let storedServer, signedIn {
            startSession(for: storedServer)
        }
        if placeholders, arguments.contains(LaunchArgument.showOffline) {
            offlineSince = Calendar.current.date(bySettingHour: 9, minute: 42, second: 0, of: .now)
        }
    }

    private func startSession(for server: ServerAddress) {
        let session = AuthSession(server: server, store: credentials)
        authSession = session
        guard !usesSampleData else {
            data = SampleDataSource(newAccount: !skipsOnboarding)
            return
        }
        cache = ResponseCache.directory(for: server).map(ResponseCache.init(directory:))
        var client = APIClient(server: server, auth: session)
        client.cache = cache
        client.onCacheUse = { [weak self] savedAt in
            Task { @MainActor in self?.cacheUsed(savedAt) }
        }
        data = client
    }

    /// An answer arrived (nil) or a kept one was shown (its save time).
    func cacheUsed(_ savedAt: Date?) {
        guard let savedAt else {
            offlineSince = nil
            return
        }
        offlineSince = min(offlineSince ?? savedAt, savedAt)
    }

    /// The app came back to the foreground: screens reload (and leave offline when they can).
    func cameToForeground() {
        foregrounds += 1
    }

    /// History was added outside the screens (an import): Today, History and Trends reload as
    /// they do after a return to the foreground.
    func historyChanged() {
        foregrounds += 1
    }

    /// Applies settings read from the server that the app also keeps locally (Calm mode), so a
    /// change made on another device shows here too.
    func adopt(_ settings: UserSettings) {
        guard settings.calmMode != calmMode else { return }
        adoptingServerSettings = true
        calmMode = settings.calmMode
        adoptingServerSettings = false
    }

    /// Sends the device's time zone when the server has none yet, so local days match the
    /// person's days. A different stored time zone is kept (the person may have chosen it);
    /// Settings offers to switch.
    func syncTimeZoneIfNeeded(device: TimeZone = .current) async {
        guard let data else { return }
        do throws(APIError) {
            let settings = try await data.settings()
            adopt(settings)
            if settings.timeZone == nil {
                _ = try await data.updateSettings(.init(timeZone: .some(device.identifier)))
            }
        } catch {
            handle(error)
        }
    }

    /// Whether meals already reached the server (the assistant was connected before the app).
    func accountHasMeals() async -> Bool {
        guard let data else { return false }
        return (try? await data.integrationStatus().lastMealSavedAt) != nil
    }

    /// Turns the notice when meals stop arriving on (after asking to post notifications) or off.
    func setArrivalNotice(_ on: Bool) async {
        if on {
            guard await noticeCenter.requestPermission() else {
                arrivalNoticeDeclined = true
                return
            }
            arrivalNoticeDeclined = false
            arrivalNoticeEnabled = true
            scheduleBackgroundRefresh()
        } else {
            arrivalNoticeEnabled = false
            noticeCenter.cancel()
            // The Apple Health sync shares the background refresh.
            scheduleBackgroundRefresh()
        }
        defaults.set(arrivalNoticeEnabled, forKey: Keys.arrivalNotice)
    }

    /// The background check: posts the notice when it is due, then asks for the next check.
    func checkArrival(now: Date = .now) async {
        guard arrivalNoticeEnabled, let data else { return }
        let state: IntegrationState
        do throws(APIError) {
            state = try await data.integrationStatus()
        } catch {
            handle(error)
            return
        }
        await postArrivalNoticeIfDue(state, now: now)
    }

    /// Posts the notice once per quiet spell and remembers which spell it was for.
    func postArrivalNoticeIfDue(_ state: IntegrationState, now: Date) async {
        let notifiedFor = defaults.object(forKey: Keys.arrivalNoticeNotifiedFor) as? Date
        guard ArrivalNotice.isDue(state, now: now, notifiedFor: notifiedFor) else { return }
        await noticeCenter.post(title: ArrivalNotice.title, body: ArrivalNotice.body)
        defaults.set(state.lastMealSavedAt, forKey: Keys.arrivalNoticeNotifiedFor)
    }


    /// Turns two-way sync with Apple Health on (after the system's access sheet, then syncs right
    /// away) or off. Off forgets where the sync stopped; the server and Apple Health keep what
    /// they have.
    func setAppleHealthSync(_ on: Bool) async {
        if on {
            guard appleHealth.isAvailable else { return }
            do {
                try await appleHealth.requestAccess()
            } catch {
                return
            }
            appleHealthSyncEnabled = true
            defaults.set(true, forKey: Keys.appleHealthSync)
            await syncAppleHealth()
            scheduleBackgroundRefresh()
        } else {
            appleHealthSyncEnabled = false
            forgetAppleHealthSync()
        }
    }

    /// One sync with Apple Health (`AppleHealthSync`): when the app becomes active, on D3's
    /// refresh and in background refresh. In the foreground it first shows the access sheet for
    /// types a newer version added (meals, for people who turned the sync on for weight).
    /// Returns how many changes it made, or nil when it did not run or failed.
    @discardableResult
    func syncAppleHealth(now: Date = .now, foreground: Bool = false) async -> Int? {
        guard appleHealthSyncEnabled, let data, !syncingAppleHealth else { return nil }
        syncingAppleHealth = true
        defer { syncingAppleHealth = false }
        if foreground { await appleHealth.requestAccessIfNeeded() }
        let changes: Int?
        do throws(APIError) {
            changes = try await healthSync.run(data, now: now)
        } catch {
            handle(error)
            return nil
        }
        if let changes, changes > 0 {
            appleHealthLastSync = now
            appleHealthLastSyncCount = changes
            defaults.set(now, forKey: Keys.appleHealthLastSync)
            defaults.set(changes, forKey: Keys.appleHealthLastSyncCount)
        }
        return changes
    }

    private func forgetAppleHealthSync() {
        healthSync.forget()
        appleHealthLastSync = nil
        appleHealthLastSyncCount = 0
        for key in Keys.appleHealth { defaults.removeObject(forKey: key) }
    }

    /// Background refresh: the arrival check, the Apple Health sync and the widgets' totals,
    /// then the next refresh.
    func backgroundRefresh() async {
        await checkArrival()
        await syncAppleHealth()
        await refreshWidgets()
        scheduleBackgroundRefresh()
    }

    /// Keeps a background refresh scheduled while signed in: the widgets need it, and iOS decides
    /// how often it really runs.
    func scheduleBackgroundRefresh() {
        if isSignedIn { noticeCenter.scheduleCheck(after: ArrivalNotice.checkEvery) }
    }

    /// Today's totals for the widgets, outside Today (background refresh).
    func refreshWidgets(now: Date = .now, calendar: Calendar = .current) async {
        guard let data else { return }
        do throws(APIError) {
            let today = try await data.days(from: now, to: now).days.first { calendar.isDate($0.date, inSameDayAs: now) }
            let settings = try await data.settings()
            let integration = try await data.integrationStatus()
            WidgetUpdates.publish(WidgetUpdates.snapshot(
                day: today, settings: settings, integration: integration, now: now, calendar: calendar))
        } catch {
            handle(error)
        }
    }

    /// Today loaded: the widgets show the same numbers, and get their own token if they have none.
    func todayLoaded(day: DayTotals?, settings: UserSettings, integration: IntegrationState) {
        WidgetUpdates.publish(WidgetUpdates.snapshot(day: day, settings: settings, integration: integration))
        Task { await ensureWidgetAccess() }
    }

    /// Gives the widgets a read-only token for this server so they fetch today's totals without
    /// the app (`WidgetAccess`). Asked once per sign-in; a failure is tried again on the next load.
    func ensureWidgetAccess(storage: any SnapshotStorage = KeychainSnapshotStorage(account: "access")) async {
        guard !usesSampleData, let server, let data else { return }
        guard WidgetAccess.load(from: storage)?.server != server.baseURL else { return }
        do throws(APIError) {
            let token = try await data.createWidgetToken()
            WidgetAccess(server: server.baseURL, token: token).save(to: storage)
            WidgetCenter.shared.reloadTimelines(ofKind: TodaySnapshot.widgetKind)
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
        // The offline copy and the widgets' totals belong to the account: signing out or deleting
        // it removes them.
        cache?.removeAll()
        WidgetUpdates.clear()
        cache = nil
        offlineSince = nil
        authSession = nil
        data = nil
        isSignedIn = false
        server = nil
        hasCompletedOnboarding = false
        defaults.removeObject(forKey: Keys.serverURL)
        defaults.removeObject(forKey: Keys.onboardingComplete)
        // The notice belongs to the account: signing out stops it.
        if arrivalNoticeEnabled { noticeCenter.cancel() }
        arrivalNoticeEnabled = false
        arrivalNoticeDeclined = false
        defaults.removeObject(forKey: Keys.arrivalNotice)
        defaults.removeObject(forKey: Keys.arrivalNoticeNotifiedFor)
        // The Apple Health sync belongs to the account too.
        appleHealthSyncEnabled = false
        forgetAppleHealthSync()
    }
}
