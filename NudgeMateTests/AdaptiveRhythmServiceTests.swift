import SwiftData
import XCTest
@testable import NudgeMate

@MainActor
final class AdaptiveRhythmServiceTests: XCTestCase {
    func testConfirmedCompletionsRecalculateAdaptiveInterval() throws {
        let context = try makeContext()
        let rhythm = makeRhythm()
        context.insert(rhythm)
        let service = AdaptiveRhythmService(
            modelContext: context,
            calendar: TestFixtures.utcCalendar
        )
        try service.seed(rhythm: rhythm, from: initialReferences)

        for date in [
            TestFixtures.date(month: 4, day: 6),
            TestFixtures.date(month: 5, day: 11),
            TestFixtures.date(month: 6, day: 15)
        ] {
            try service.recordCompletion(for: rhythm, source: .dailyRecap, at: date)
        }

        let records = try context.fetch(FetchDescriptor<RhythmOccurrenceRecord>())
        XCTAssertEqual(records.count, 6)
        XCTAssertEqual(rhythm.baseIntervalDays, 35)
        XCTAssertEqual(rhythm.historyDates.count, 6)
        XCTAssertEqual(rhythm.lastOccurrenceDate, TestFixtures.date(month: 6, day: 15))
        XCTAssertEqual(
            rhythm.nextExpectedCenterDate,
            TestFixtures.date(month: 7, day: 20)
        )
    }

    func testScheduledOccurrenceIsStoredWithoutTeachingTheInterval() throws {
        let context = try makeContext()
        let rhythm = makeRhythm()
        context.insert(rhythm)
        let service = AdaptiveRhythmService(
            modelContext: context,
            calendar: TestFixtures.utcCalendar
        )
        try service.seed(rhythm: rhythm, from: initialReferences)

        try service.recordScheduled(
            for: rhythm,
            at: TestFixtures.date(month: 8, day: 1),
            calendarIdentifier: "personal",
            eventIdentifier: "scheduled-event"
        )
        _ = try service.recalculate(rhythm, now: TestFixtures.date(month: 4, day: 1))

        let records = try context.fetch(FetchDescriptor<RhythmOccurrenceRecord>())
        XCTAssertEqual(records.count, 4)
        XCTAssertEqual(records.filter { $0.status == .scheduled }.count, 1)
        XCTAssertEqual(rhythm.baseIntervalDays, 30)
        XCTAssertEqual(rhythm.lastOccurrenceDate, TestFixtures.date(month: 3, day: 2))
    }

    func testCalendarReconciliationAddsNewObservationAndRecalculates() throws {
        let context = try makeContext()
        let rhythm = makeRhythm()
        context.insert(rhythm)
        let service = AdaptiveRhythmService(
            modelContext: context,
            calendar: TestFixtures.utcCalendar
        )
        try service.seed(rhythm: rhythm, from: initialReferences)
        let event = TestFixtures.snapshot(
            title: "Haircut",
            normalizedTitle: "haircut",
            day: 97,
            calendarIdentifier: "personal"
        )

        let changed = try service.reconcile(
            events: [event],
            rhythms: [rhythm],
            selectedCalendarIdentifiers: ["personal"],
            now: TestFixtures.date(month: 4, day: 15)
        )

        XCTAssertEqual(changed.map(\.id), [rhythm.id])
        XCTAssertEqual(rhythm.lastOccurrenceDate, event.startDate)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<RhythmOccurrenceRecord>()).count,
            4
        )
    }

    func testGenericTitleDoesNotAutoAttachWithoutStoredContext() throws {
        let context = try makeContext()
        let rhythm = makeRhythm(title: "병원", normalizedName: "병원")
        context.insert(rhythm)
        let service = AdaptiveRhythmService(
            modelContext: context,
            calendar: TestFixtures.utcCalendar
        )
        try service.seed(rhythm: rhythm, from: initialReferences)

        let changed = try service.reconcile(
            events: [
                TestFixtures.snapshot(
                    title: "병원",
                    normalizedTitle: "병원",
                    day: 97,
                    calendarIdentifier: "personal",
                    location: "다른 병원"
                )
            ],
            rhythms: [rhythm],
            selectedCalendarIdentifiers: ["personal"],
            now: TestFixtures.date(month: 4, day: 15)
        )

        XCTAssertTrue(changed.isEmpty)
    }

    private var initialReferences: [CandidateEventReference] {
        [
            ("event-1", TestFixtures.date(month: 1, day: 1)),
            ("event-2", TestFixtures.date(month: 1, day: 31)),
            ("event-3", TestFixtures.date(month: 3, day: 2))
        ].map { identifier, date in
            CandidateEventReference(
                eventIdentifier: identifier,
                calendarIdentifier: "personal",
                originalTitle: "Haircut",
                occurredAt: date,
                isIncluded: true
            )
        }
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try PersistenceController.makeContainer(inMemory: true))
    }

    private func makeRhythm(
        title: String = "Haircut",
        normalizedName: String = "haircut"
    ) -> RecurringEvent {
        let rhythm = RecurringEvent(
            title: title,
            baseInterval: 30,
            historyDates: [],
            nextPredictedDate: TestFixtures.date(month: 4, day: 1)
        )
        rhythm.normalizedName = normalizedName
        rhythm.mode = .adaptive
        rhythm.sourceCalendarIdentifiers = ["personal"]
        return rhythm
    }
}
