import SwiftData
import UserNotifications
import XCTest
@testable import NudgeMate

@MainActor
final class NotificationReliabilityTests: XCTestCase {
    func testMutedStateUpdatesNotificationAndLifecycleTogether() {
        let event = RecurringEvent(
            title: "Dental checkup",
            baseInterval: 180,
            historyDates: [.now],
            nextPredictedDate: .now.addingTimeInterval(86_400)
        )

        event.isMuted = true
        XCTAssertFalse(event.notificationsEnabled)
        XCTAssertEqual(event.lifecycleState, .paused)
        XCTAssertTrue(event.isMuted)

        event.isMuted = false
        XCTAssertTrue(event.notificationsEnabled)
        XCTAssertEqual(event.lifecycleState, .active)
        XCTAssertFalse(event.isMuted)
    }

    func testStoredGenericPrivacyModeIsAppliedToRhythmNotification() async throws {
        let scheduler = CapturingNotificationScheduler()
        let manager = NudgeManager(scheduler: scheduler, calendar: TestFixtures.utcCalendar)
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        var settings = try SwiftDataSettingsRepository(context: context).load()
        settings.privacyNotificationMode = .generic
        try SwiftDataSettingsRepository(context: context).save(settings)
        manager.configure(modelContainer: container)

        let event = RecurringEvent(
            title: "Private appointment",
            baseInterval: 30,
            historyDates: [TestFixtures.date(day: 1)],
            nextPredictedDate: TestFixtures.date(month: 12, day: 20)
        )
        try await manager.scheduleNudge(for: event)

        let capturedDescriptor = await scheduler.lastDescriptor()
        let descriptor = try XCTUnwrap(capturedDescriptor)
        XCTAssertEqual(
            descriptor.title,
            NudgeMateStrings.Localizable.Notification.Generic.title
        )
        XCTAssertEqual(
            descriptor.body,
            NudgeMateStrings.Localizable.Notification.Generic.body
        )
        XCTAssertFalse(descriptor.title.contains(event.title))
    }

    func testNotificationBodyTapRoutesToItsPrep() {
        let prepID = UUID()
        let payload = NotificationPayload(
            prepPlanID: prepID,
            deepLink: "nudgemate://prep/\(prepID.uuidString)"
        )

        XCTAssertEqual(
            NotificationActionRouter.navigationDestination(
                actionIdentifier: UNNotificationDefaultActionIdentifier,
                payload: payload
            ),
            .prep(prepID)
        )
    }

    func testNotificationScheduleActionRoutesToRhythmReview() {
        let rhythmID = UUID()
        XCTAssertEqual(
            NotificationActionRouter.navigationDestination(
                actionIdentifier: NotificationActionIdentifier.rhythmOpenScheduler,
                payload: NotificationPayload(rhythmID: rhythmID)
            ),
            .scheduleRhythm(rhythmID)
        )
    }
}

private actor CapturingNotificationScheduler: NotificationScheduling {
    private var descriptors: [LocalNotificationDescriptor] = []

    func permissionState() async -> NotificationPermissionState { .authorized }

    func requestAuthorization() async throws -> Bool { true }

    func reconcile(_ descriptors: [LocalNotificationDescriptor]) async throws {
        self.descriptors = descriptors
    }

    func cancel(identifiers: [String]) async {
        descriptors.removeAll { identifiers.contains($0.identifier) }
    }

    func cancelAll() async {
        descriptors.removeAll()
    }

    func lastDescriptor() -> LocalNotificationDescriptor? {
        descriptors.last
    }
}
