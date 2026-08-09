import XCTest
@testable import NudgeMate

final class IntervalEstimatorTests: XCTestCase {
    private let estimator = IntervalEstimator(calendar: TestFixtures.utcCalendar)

    func testExcludesLargeOutlier() throws {
        let result = try estimator.estimate(
            from: TestFixtures.occurrences(intervals: [35, 37, 36, 82, 38])
        )
        XCTAssertEqual(result.baseIntervalDays, 37)
        XCTAssertEqual(result.outlierCount, 1)
        XCTAssertTrue(result.samples.contains { $0.days == 82 && $0.isOutlier })
    }

    func testStableThirtyDayRhythm() throws {
        let result = try estimator.estimate(
            from: TestFixtures.occurrences(intervals: [30, 30, 30, 30])
        )
        XCTAssertEqual(result.baseIntervalDays, 30)
        XCTAssertEqual(result.variationDays, 2)
    }

    func testRequiresAtLeastThreeOccurrences() {
        let values = Array(TestFixtures.occurrences(intervals: [30]).prefix(2))
        XCTAssertThrowsError(try estimator.estimate(from: values)) { error in
            XCTAssertEqual(error as? IntervalEstimatorError, .insufficientOccurrences)
        }
    }

    func testIgnoresScheduledOccurrence() throws {
        var values = TestFixtures.occurrences(intervals: [30, 30, 30])
        values.insert(
            RhythmOccurrence(
                id: UUID(),
                rhythmID: UUID(),
                occurredAt: TestFixtures.date(day: 15),
                source: .scheduledCalendarEvent,
                status: .scheduled,
                evidenceWeight: 0,
                sourceCalendarIdentifier: nil,
                sourceEventIdentifier: nil,
                userConfirmed: false,
                excludedAsOutlier: false,
                createdAt: TestFixtures.date(day: 15),
                updatedAt: TestFixtures.date(day: 15)
            ),
            at: 1
        )
        XCTAssertEqual(try estimator.estimate(from: values).baseIntervalDays, 30)
    }

    func testDeduplicatesSameDayOccurrences() throws {
        var values = TestFixtures.occurrences(intervals: [30, 30, 30])
        values.append(values[1])
        XCTAssertEqual(try estimator.estimate(from: values).validOccurrenceCount, 4)
    }
}
