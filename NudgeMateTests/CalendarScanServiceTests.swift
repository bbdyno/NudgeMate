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

    func testKnownRhythmSignatureIsNotSuggestedAgain() {
        let events = [1, 31, 61].map {
            TestFixtures.snapshot(title: "Haircut", normalizedTitle: "haircut", day: $0)
        }
        let result = CalendarScanService(calendar: TestFixtures.utcCalendar).scan(
            events: events,
            knownSignatures: ["haircut"],
            referenceDate: TestFixtures.date(month: 4, day: 1)
        )
        XCTAssertTrue(result.candidates.isEmpty)
    }

    func testSimilarTitlesAcrossDifferentPrimaryBlockingKeysAreGrouped() {
        let events = [
            TestFixtures.snapshot(
                title: "Alpha dental cleaning recurring service",
                normalizedTitle: "alpha dental cleaning recurring service",
                day: 1,
                location: "Smile Clinic"
            ),
            TestFixtures.snapshot(
                title: "Beta dental cleaning recurring service",
                normalizedTitle: "beta dental cleaning recurring service",
                day: 31,
                location: "Smile Clinic"
            ),
            TestFixtures.snapshot(
                title: "Gamma dental cleaning recurring service",
                normalizedTitle: "gamma dental cleaning recurring service",
                day: 61,
                location: "Smile Clinic"
            )
        ]

        let groups = PatternCandidateDetector(calendar: TestFixtures.utcCalendar).groups(from: events)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.count, 3)
    }

    func testGenericExactTitlesNeedMatchingCalendarAndLocationContext() {
        let events = [
            TestFixtures.snapshot(
                title: "병원",
                normalizedTitle: "병원",
                day: 1,
                calendarIdentifier: "personal",
                location: "서울 의원"
            ),
            TestFixtures.snapshot(
                title: "병원",
                normalizedTitle: "병원",
                day: 31,
                calendarIdentifier: "personal",
                location: "서울 의원"
            ),
            TestFixtures.snapshot(
                title: "병원",
                normalizedTitle: "병원",
                day: 5,
                calendarIdentifier: "family",
                location: "부산 병원"
            ),
            TestFixtures.snapshot(
                title: "병원",
                normalizedTitle: "병원",
                day: 35,
                calendarIdentifier: "family",
                location: "부산 병원"
            )
        ]

        let groups = PatternCandidateDetector(calendar: TestFixtures.utcCalendar).groups(from: events)

        XCTAssertTrue(groups.isEmpty)
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
