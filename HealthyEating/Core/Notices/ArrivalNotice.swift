import BackgroundTasks
import Foundation
import UserNotifications

/// The opt-in notice when meals stop arriving (Settings, "Notice when meals stop arriving").
///
/// A background app refresh reads the integration status and posts one local notification when
/// the server reports `quiet` and the last meal arrived more than two days ago. One per quiet
/// spell: a new meal re-arms it. Local notifications only, so self-hosters need no push keys.
/// The wording is about the integration, never about the person's eating or logging.
nonisolated enum ArrivalNotice {
    static let taskIdentifier = "io.github.valtronforever.HealthyEating.arrival-check"
    static let notificationIdentifier = "arrival-notice"
    /// The design's promise: "One quiet notification after 2 days".
    static let quietFor: TimeInterval = 2 * 24 * 3600
    /// The earliest next check; iOS decides when it really runs.
    static let checkEvery: TimeInterval = 6 * 3600

    /// Whether the notice is due: quiet for two days and not yet sent for this quiet spell.
    static func isDue(_ state: IntegrationState, now: Date, notifiedFor: Date?) -> Bool {
        guard state.arrival == .quiet, let lastSaved = state.lastMealSavedAt else { return false }
        return now.timeIntervalSince(lastSaved) >= quietFor && notifiedFor != lastSaved
    }

    static var title: String { String(localized: "Your assistant may not be saving meals") }
    static var body: String {
        String(localized: "No meals saved in the last 2 days. If you logged food, check that your assistant is still connected.")
    }
}

/// Notifications and background checks, behind a protocol so tests and screenshots never touch
/// the system.
protocol ArrivalNoticeCenter {
    /// Asks for permission to post notifications; false when the person declined.
    func requestPermission() async -> Bool
    func post(title: String, body: String) async
    /// Asks iOS to run the background check again after `delay`.
    func scheduleCheck(after delay: TimeInterval)
    /// Stops background checks and removes a notice that was posted.
    func cancel()
}

struct SystemArrivalNoticeCenter: ArrivalNoticeCenter {
    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func post(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: ArrivalNotice.notificationIdentifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleCheck(after delay: TimeInterval) {
        let request = BGAppRefreshTaskRequest(identifier: ArrivalNotice.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: delay)
        // Fails where background refresh is unavailable (the simulator, or turned off by the
        // person); the notice then simply never comes, which is the quiet default.
        try? BGTaskScheduler.shared.submit(request)
    }

    func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: ArrivalNotice.taskIdentifier)
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [ArrivalNotice.notificationIdentifier])
        center.removePendingNotificationRequests(withIdentifiers: [ArrivalNotice.notificationIdentifier])
    }
}

/// UI tests and screenshots: permission is granted, nothing reaches the system.
final class PlaceholderArrivalNoticeCenter: ArrivalNoticeCenter {
    private(set) var posted: [(title: String, body: String)] = []
    private(set) var scheduledChecks = 0
    private(set) var cancelled = 0
    var grantsPermission = true

    func requestPermission() async -> Bool { grantsPermission }
    func post(title: String, body: String) async { posted.append((title, body)) }
    func scheduleCheck(after delay: TimeInterval) { scheduledChecks += 1 }
    func cancel() { cancelled += 1 }
}
