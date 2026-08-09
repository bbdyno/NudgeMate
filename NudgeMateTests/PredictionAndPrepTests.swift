import XCTest
@testable import NudgeMate

final class PredictionAndPrepTests: XCTestCase {
    private let calendar = TestFixtures.utcCalendar

    func testPredictionBuildsExpectedWindowAndLeadDate() {
        let estimate = IntervalEstimate(
            baseIntervalDays: 30,
            medianIntervalDays: 30,
            variationDays: 3,
            robustSigma: 1,
            samples: [],
            validOccurrenceCount: 5
        )
        let last = TestFixtures.date(day: 1)
        let result = PredictionEngine(calendar: calendar).predict(
            lastOccurrence: last,
            estimate: estimate,
            leadTimeDays: 3,
            now: TestFixtures.date(day: 10)
        )
        XCTAssertEqual(calendar.dateComponents([.day], from: last, to: result.expectedWindow.center).day, 30)
        XCTAssertEqual(calendar.dateComponents([.day], from: result.notificationDate, to: result.expectedWindow.start).day, 3)
        XCTAssertEqual(result.timingState, .upcoming)
    }

    func testOneExceptionDoesNotSuggestAdjustment() {
        let engine = PredictionEngine(calendar: calendar)
        let values = [0, 0, 8, 0].enumerated().map { index, shift in
            let scheduled = TestFixtures.date(month: 1, day: 1 + index * 10)
            return (
                scheduled,
                calendar.date(byAdding: .day, value: shift, to: scheduled) ?? scheduled
            )
        }
        XCTAssertNil(engine.adjustmentProposal(currentIntervalDays: 39, recentScheduledAndCompleted: values))
    }

    func testThreeConsistentDelaysSuggestAdjustment() {
        let engine = PredictionEngine(calendar: calendar)
        let values = [8, 7, 9, 0].enumerated().map { index, shift in
            let scheduled = TestFixtures.date(month: 1, day: 1 + index * 10)
            return (
                scheduled,
                calendar.date(byAdding: .day, value: shift, to: scheduled) ?? scheduled
            )
        }
        XCTAssertEqual(
            engine.adjustmentProposal(
                currentIntervalDays: 39,
                recentScheduledAndCompleted: values
            )?.suggestedIntervalDays,
            47
        )
    }

    func testTwentyDaysNotReadySchedulesFourDaysLater() {
        let now = TestFixtures.date(day: 1)
        let target = calendar.date(byAdding: .day, value: 20, to: now) ?? now
        let result = PrepScheduleCalculator(calendar: calendar).nextCheckIn(
            now: now,
            targetDate: target,
            status: .notReady,
            intensity: .normal
        )
        guard case let .scheduled(date) = result else {
            return XCTFail("scheduled 상태가 필요합니다.")
        }
        XCTAssertEqual(calendar.dateComponents([.day], from: now, to: date).day, 4)
    }

    func testTwentyDaysInProgressUsesPeriodMaximum() {
        let now = TestFixtures.date(day: 1)
        let target = calendar.date(byAdding: .day, value: 20, to: now) ?? now
        let result = PrepScheduleCalculator(calendar: calendar).nextCheckIn(
            now: now,
            targetDate: target,
            status: .inProgress,
            intensity: .normal
        )
        guard case let .scheduled(date) = result else {
            return XCTFail("scheduled 상태가 필요합니다.")
        }
        XCTAssertEqual(calendar.dateComponents([.day], from: now, to: date).day, 5)
    }

    func testReadyStopsAndPastTargetEndsSchedule() {
        let calculator = PrepScheduleCalculator(calendar: calendar)
        let now = TestFixtures.date(day: 10)
        XCTAssertEqual(
            calculator.nextCheckIn(
                now: now,
                targetDate: TestFixtures.date(day: 20),
                status: .ready,
                intensity: .normal
            ),
            .stopped
        )
        XCTAssertEqual(
            calculator.nextCheckIn(
                now: now,
                targetDate: TestFixtures.date(day: 9),
                status: .notReady,
                intensity: .normal
            ),
            .targetPassed
        )
    }

    func testNoResponseRetryIsLimitedToOnce() {
        let calculator = PrepScheduleCalculator(calendar: calendar)
        XCTAssertTrue(calculator.shouldScheduleRetry(retryCount: 0))
        XCTAssertFalse(calculator.shouldScheduleRetry(retryCount: 1))
    }
}
