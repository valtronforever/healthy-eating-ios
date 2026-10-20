import Foundation
import Testing
@testable import HealthyEating

struct ArrivalNoticeRuleTests {
    private let now = Date(timeIntervalSince1970: 1_792_000_000)
    private let day: TimeInterval = 24 * 3600

    private func state(_ arrival: ArrivalStatus, savedDaysAgo days: Double?) -> IntegrationState {
        IntegrationState(
            lastMealSavedAt: days.map { now.addingTimeInterval(-$0 * day) },
            lastAssistant: "Claude",
            mealsToday: 0,
            arrival: arrival
        )
    }

    @Test func dueAfterTwoQuietDays() {
        #expect(ArrivalNotice.isDue(state(.quiet, savedDaysAgo: 2), now: now, notifiedFor: nil))
        #expect(!ArrivalNotice.isDue(state(.quiet, savedDaysAgo: 1.9), now: now, notifiedFor: nil))
    }

    @Test func onlyWhenTheServerSaysQuiet() {
        #expect(!ArrivalNotice.isDue(state(.ok, savedDaysAgo: 3), now: now, notifiedFor: nil))
        #expect(!ArrivalNotice.isDue(state(.unknown, savedDaysAgo: 3), now: now, notifiedFor: nil))
        #expect(!ArrivalNotice.isDue(state(.quiet, savedDaysAgo: nil), now: now, notifiedFor: nil))
    }

    @Test func oncePerQuietSpell() {
        let quiet = state(.quiet, savedDaysAgo: 3)
        #expect(!ArrivalNotice.isDue(quiet, now: now, notifiedFor: quiet.lastMealSavedAt))
        // A meal arrived since the last notice, then it went quiet again: due again.
        let later = state(.quiet, savedDaysAgo: 2.5)
        #expect(ArrivalNotice.isDue(later, now: now, notifiedFor: quiet.lastMealSavedAt))
    }

    @Test func wordingIsAboutTheIntegration() {
        let text = (ArrivalNotice.title + " " + ArrivalNotice.body).lowercased()
        #expect(text.contains("assistant"))
        for judgment in ["forgot", "forget", "should", "missed"] {
            #expect(!text.contains(judgment))
        }
    }
}

@MainActor
struct ArrivalNoticeSettingTests {
    private func model(_ center: PlaceholderArrivalNoticeCenter) -> (AppModel, UserDefaults) {
        let defaults = UserDefaults(suiteName: "ArrivalNoticeTests.\(UUID())")!
        let model = AppModel(defaults: defaults, arguments: [AppModel.LaunchArgument.skipOnboarding], noticeCenter: center)
        return (model, defaults)
    }

    @Test func offByDefault() {
        let (model, _) = model(PlaceholderArrivalNoticeCenter())
        #expect(!model.arrivalNoticeEnabled)
    }

    @Test func turningOnAsksForPermissionAndSchedules() async {
        let center = PlaceholderArrivalNoticeCenter()
        let (model, defaults) = model(center)

        await model.setArrivalNotice(true)

        #expect(model.arrivalNoticeEnabled)
        #expect(defaults.bool(forKey: "arrivalNotice"))
        #expect(center.scheduledChecks == 1)
        await model.setArrivalNotice(false)
        #expect(!model.arrivalNoticeEnabled)
        #expect(center.cancelled == 1)
    }

    @Test func staysOffWhenNotificationsAreDeclined() async {
        let center = PlaceholderArrivalNoticeCenter()
        center.grantsPermission = false
        let (model, _) = model(center)

        await model.setArrivalNotice(true)

        #expect(!model.arrivalNoticeEnabled)
        #expect(model.arrivalNoticeDeclined)
        #expect(center.scheduledChecks == 0)
    }

    @Test func checkDoesNothingWhileOff() async {
        let center = PlaceholderArrivalNoticeCenter()
        let (model, _) = model(center)

        await model.checkArrival()

        #expect(center.posted.isEmpty)
        #expect(center.scheduledChecks == 0)
    }

    @Test func checkPostsNothingWhileMealsArriveAndSchedulesTheNext() async {
        let center = PlaceholderArrivalNoticeCenter()
        let (model, _) = model(center)
        await model.setArrivalNotice(true)

        await model.checkArrival()

        #expect(center.posted.isEmpty, "the sample account's meals arrive as usual")
        #expect(center.scheduledChecks == 2)
    }

    @Test func postsOncePerQuietSpell() async {
        let center = PlaceholderArrivalNoticeCenter()
        let (model, _) = model(center)
        let now = Date.now
        let quiet = IntegrationState(
            lastMealSavedAt: now.addingTimeInterval(-3 * 24 * 3600), lastAssistant: "Claude", mealsToday: 0, arrival: .quiet
        )

        await model.postArrivalNoticeIfDue(quiet, now: now)
        await model.postArrivalNoticeIfDue(quiet, now: now.addingTimeInterval(6 * 3600))

        #expect(center.posted.count == 1)
        #expect(center.posted.first?.title == ArrivalNotice.title)
    }

    @Test func signingOutStopsTheNotice() async {
        let center = PlaceholderArrivalNoticeCenter()
        let (model, defaults) = model(center)
        await model.setArrivalNotice(true)

        await model.signOut()

        #expect(!model.arrivalNoticeEnabled)
        #expect(center.cancelled == 1)
        #expect(!defaults.bool(forKey: "arrivalNotice"))
    }
}
