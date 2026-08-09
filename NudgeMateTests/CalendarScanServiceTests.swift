import XCTest
@testable import NudgeMate

final class CalendarScanServiceTests: XCTestCase {
    func testBuildsCandidateFromThreeMatchingEvents() {
        let events = [1, 31, 61].map {
            TestFixtures.snapshot(
                title: "Haircut Appointment",
                normalizedTitle: "haircut",
                day: $0
            )
        }
        let result = CalendarScanService(calendar: TestFixtures.utcCalendar).scan(
            events: events,
            referenceDate: TestFixtures.date(month: 4, day: 1)
        )
        XCTAssertEqual(result.scannedEventCount, 3)
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.candidates.first?.medianIntervalDays, 30)
    }

    func testSuppressedSignatureIsNotSuggestedAgain() {
        let events = [1, 31, 61].map {
            TestFixtures.snapshot(title: "Haircut", normalizedTitle: "haircut", day: $0)
        }
        let result = CalendarScanService(calendar: TestFixtures.utcCalendar).scan(
            events: events,
            suppressedSignatures: ["haircut"],
            referenceDate: TestFixtures.date(month: 4, day: 1)
        )
        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testTenThousandEventsUseBlockingKeys() {
        let events = (0..<10_000).map { index in
            TestFixtures.snapshot(
                title: "Event \(index)",
                normalizedTitle: "event \(index)",
                day: index % 27 + 1
            )
        }
        measure {
            _ = PatternCandidateDetector(calendar: TestFixtures.utcCalendar).groups(from: events)
        }
    }
}
