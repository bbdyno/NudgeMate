import SwiftData
import XCTest
@testable import NudgeMate

@MainActor
final class HomeConsistencyTests: XCTestCase {
    func testSummaryPriorityAndPreviewUseTheSameActionableSet() {
        let now = TestFixtures.date(day: 5)
        let firstRhythm = makeRhythm(title: "Haircut", nextDay: 20)
        let secondRhythm = makeRhythm(title: "Dental", nextDay: 30)
        let mutedRhythm = makeRhythm(title: "Muted", nextDay: 6, isMuted: true)
        let activePrep = EventPrep(
            title: "Trip",
            targetDate: TestFixtures.date(day: 10),
            nextReminderDate: now
        )
        let readyPrep = EventPrep(
            title: "Ready",
            targetDate: TestFixtures.date(day: 7),
            status: .ready,
            nextReminderDate: now
        )
        let pastPrep = EventPrep(
            title: "Past",
            targetDate: TestFixtures.date(day: 4),
            nextReminderDate: now
        )

        let snapshot = HomeDashboardSnapshot(
            rhythms: [secondRhythm, mutedRhythm, firstRhythm],
            preps: [readyPrep, pastPrep, activePrep],
            now: now,
            calendar: TestFixtures.utcCalendar
        )

        XCTAssertEqual(snapshot.itemCount, 3)
        XCTAssertEqual(snapshot.prepIDs, [activePrep.id])
        XCTAssertEqual(snapshot.rhythmIDs, [firstRhythm.id, secondRhythm.id])
        XCTAssertEqual(snapshot.rhythmPreviewIDs, [firstRhythm.id, secondRhythm.id])
        XCTAssertEqual(snapshot.priority, .prep(activePrep.id))
    }

    func testRhythmBecomesPriorityWhenThereIsNoActivePrep() {
        let rhythm = makeRhythm(title: "Haircut", nextDay: 20)

        let snapshot = HomeDashboardSnapshot(
            rhythms: [rhythm],
            preps: [],
            now: TestFixtures.date(day: 5),
            calendar: TestFixtures.utcCalendar
        )

        XCTAssertEqual(snapshot.itemCount, 1)
        XCTAssertEqual(snapshot.priority, .rhythm(rhythm.id))
    }

    func testTurningOffRhythmRemovesItFromEveryHomeValue() {
        let rhythm = makeRhythm(title: "Haircut", nextDay: 20)
        rhythm.isMuted = true

        let snapshot = HomeDashboardSnapshot(
            rhythms: [rhythm],
            preps: [],
            now: TestFixtures.date(day: 5),
            calendar: TestFixtures.utcCalendar
        )

        XCTAssertEqual(snapshot.itemCount, 0)
        XCTAssertNil(snapshot.priority)
        XCTAssertTrue(snapshot.rhythmIDs.isEmpty)
        XCTAssertTrue(snapshot.rhythmPreviewIDs.isEmpty)
    }

    func testHomeLoadDoesNotRecreateCalendarRhythms() async throws {
        let calendarStore = SeededCalendarStore(events: [
            TestFixtures.snapshot(title: "Haircut", normalizedTitle: "haircut", day: 1),
            TestFixtures.snapshot(title: "Haircut", normalizedTitle: "haircut", day: 31),
            TestFixtures.snapshot(title: "Haircut", normalizedTitle: "haircut", day: 61)
        ])
        let eventKitManager = EventKitManager(
            store: calendarStore,
            calendar: TestFixtures.utcCalendar
        )
        let nudgeManager = NudgeManager(scheduler: DeniedNotificationScheduler())
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)

        await HomeViewModel().load(
            modelContext: context,
            eventKitManager: eventKitManager,
            nudgeManager: nudgeManager
        )

        XCTAssertTrue(try context.fetch(FetchDescriptor<RecurringEvent>()).isEmpty)
        let eventFetchCount = await calendarStore.eventFetchCount()
        XCTAssertEqual(eventFetchCount, 0)
    }

    func testDeletingDiscoveredRhythmRemovesDependentsAndSuppressesRediscovery() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let rhythm = makeRhythm(title: "Haircut", nextDay: 20)
        rhythm.normalizedName = "haircut"
        rhythm.origin = .discovered
        rhythm.sourceCalendarIdentifiers = ["personal"]
        context.insert(rhythm)
        context.insert(
            RhythmOccurrenceRecord(
                value: RhythmOccurrence(
                    id: UUID(),
                    rhythmID: rhythm.id,
                    occurredAt: TestFixtures.date(day: 1),
                    source: .calendarObserved,
                    status: .observed,
                    evidenceWeight: 0.6,
                    sourceCalendarIdentifier: "personal",
                    sourceEventIdentifier: "event-1",
                    userConfirmed: false,
                    excludedAsOutlier: false,
                    createdAt: TestFixtures.date(day: 1),
                    updatedAt: TestFixtures.date(day: 1)
                )
            )
        )
        context.insert(
            NudgeInstanceRecord(
                value: NudgeInstance(
                    id: UUID(),
                    rhythmID: rhythm.id,
                    expectedWindow: DateWindow(
                        start: rhythm.nextExpectedStartDate,
                        center: rhythm.nextExpectedCenterDate,
                        end: rhythm.nextExpectedEndDate
                    ),
                    scheduledNotificationDate: nil,
                    deliveredDate: nil,
                    state: .planned,
                    snoozeCount: 0,
                    lastAction: nil,
                    actionTakenAt: nil,
                    linkedCreatedEventIdentifier: nil,
                    createdAt: TestFixtures.date(day: 1),
                    updatedAt: TestFixtures.date(day: 1)
                )
            )
        )
        try context.save()

        try RhythmDeletionService(calendar: TestFixtures.utcCalendar).delete(
            [rhythm],
            in: context,
            now: TestFixtures.date(day: 5)
        )

        XCTAssertTrue(try context.fetch(FetchDescriptor<RecurringEvent>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RhythmOccurrenceRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<NudgeInstanceRecord>()).isEmpty)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<SuppressedPatternRecord>())
                .map(\.normalizedSignature),
            ["haircut"]
        )
    }

    private func makeRhythm(
        title: String,
        nextDay: Int,
        isMuted: Bool = false
    ) -> RecurringEvent {
        RecurringEvent(
            title: title,
            baseInterval: 30,
            historyDates: [TestFixtures.date(day: 1)],
            nextPredictedDate: TestFixtures.date(day: nextDay),
            isMuted: isMuted
        )
    }
}

private actor SeededCalendarStore: CalendarStore {
    private let storedEvents: [CalendarEventSnapshot]
    private var fetchCount = 0

    init(events: [CalendarEventSnapshot]) {
        storedEvents = events
    }

    func authorizationState() async -> CalendarAuthorizationState { .fullAccess }
    func requestFullAccess() async throws {}
    func calendars() async throws -> [CalendarDescriptor] { [] }

    func events(
        from startDate: Date,
        to endDate: Date,
        calendarIdentifiers: Set<String>
    ) async throws -> [CalendarEventSnapshot] {
        fetchCount += 1
        return storedEvents
    }

    func createEvent(_ draft: CalendarEventDraft) async throws -> String { "event" }
    func eventFetchCount() -> Int { fetchCount }
}

private actor DeniedNotificationScheduler: NotificationScheduling {
    func permissionState() async -> NotificationPermissionState { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func reconcile(_ descriptors: [LocalNotificationDescriptor]) async throws {}
    func cancel(identifiers: [String]) async {}
    func cancelAll() async {}
}
