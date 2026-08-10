import Foundation
import XCTest
@testable import NudgeMate

final class WidgetSnapshotTests: XCTestCase {
    private let calendar = TestFixtures.utcCalendar

    func testSnapshotKeepsNearestIncompletePrepsAndAppliesLimit() {
        let now = TestFixtures.date(day: 10)
        let items = [
            item(title: "Later", day: 20, status: .notReady),
            item(title: "Ready", day: 11, status: .ready),
            item(title: "Past", day: 9, status: .inProgress),
            item(title: "First", day: 12, status: .inProgress),
            item(title: "Second", day: 13, status: .notReady),
            item(title: "Third", day: 14, status: .notReady)
        ]

        let snapshot = PrepWidgetSnapshot.make(
            items: items,
            at: now,
            calendar: calendar,
            limit: 3
        )

        XCTAssertEqual(snapshot.items.map(\.title), ["First", "Second", "Third"])
    }

    func testWidgetItemBuildsPrepDeepLinkAndDayCount() {
        let item = item(title: "Trip", day: 15, status: .notReady)

        XCTAssertEqual(item.deepLinkURL?.scheme, "nudgemate")
        XCTAssertEqual(item.deepLinkURL?.host, "prep")
        XCTAssertTrue(item.deepLinkURL?.absoluteString.hasSuffix(item.id.uuidString) == true)
        XCTAssertEqual(
            item.daysRemaining(at: TestFixtures.date(day: 10), calendar: calendar),
            5
        )
    }

    func testSnapshotStoreRoundTripsUsingInjectedDefaults() throws {
        let suiteName = "WidgetSnapshotTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let snapshot = PrepWidgetSnapshot.make(
            items: [item(title: "Presentation", day: 12, status: .inProgress)],
            at: TestFixtures.date(day: 10),
            calendar: calendar
        )

        XCTAssertTrue(PrepWidgetSnapshotStore.save(snapshot, defaults: defaults))
        XCTAssertEqual(PrepWidgetSnapshotStore.load(defaults: defaults), snapshot)
    }

    func testSurfaceContentIsPrivateAndBounded() {
        let longValue = String(repeating: "준비", count: 200)

        XCTAssertEqual(
            PrepSurfaceContentSanitizer.title(longValue, showsDetails: true).count,
            PrepSurfaceContentSanitizer.maximumTitleLength
        )
        XCTAssertEqual(
            PrepSurfaceContentSanitizer.nextAction(longValue, showsDetails: true).count,
            PrepSurfaceContentSanitizer.maximumNextActionLength
        )
        XCTAssertTrue(PrepSurfaceContentSanitizer.title(longValue, showsDetails: false).isEmpty)
        XCTAssertTrue(PrepSurfaceContentSanitizer.nextAction(longValue, showsDetails: false).isEmpty)
    }

    private func item(
        title: String,
        day: Int,
        status: SharedPrepStatus
    ) -> PrepWidgetItem {
        PrepWidgetItem(
            id: UUID(),
            title: title,
            targetDate: TestFixtures.date(day: day),
            status: status,
            nextAction: "",
            showsDetails: true
        )
    }
}
