import XCTest
@testable import NudgeMate

final class EventSimilarityCalculatorTests: XCTestCase {
    private let calculator = EventSimilarityCalculator()

    func testSameMeaningAfterNormalizationHasHighSimilarity() {
        let lhs = TestFixtures.snapshot(title: "미용실 예약", normalizedTitle: "미용실")
        let rhs = TestFixtures.snapshot(title: "미용실", normalizedTitle: "미용실")
        XCTAssertGreaterThanOrEqual(calculator.score(lhs, rhs), 0.85)
    }

    func testRelatedHaircutTitlesHaveModerateSimilarity() {
        let lhs = TestFixtures.snapshot(title: "준오헤어 커트", normalizedTitle: "준오헤어 커트")
        let rhs = TestFixtures.snapshot(title: "헤어샵 커트", normalizedTitle: "헤어샵 커트")
        XCTAssertGreaterThan(calculator.score(lhs, rhs), 0.30)
    }

    func testGenericSingleTokenDoesNotAutomaticallyMerge() {
        let lhs = TestFixtures.snapshot(title: "병원", normalizedTitle: "병원")
        let rhs = TestFixtures.snapshot(title: "병원", normalizedTitle: "병원")
        XCTAssertLessThan(calculator.score(lhs, rhs), calculator.configuration.mergeThreshold)
    }

    func testDifferentK5MaintenanceCanRemainSeparate() {
        let lhs = TestFixtures.snapshot(title: "K5 엔진오일", normalizedTitle: "k5 엔진오일")
        let rhs = TestFixtures.snapshot(title: "K5 타이어 교체", normalizedTitle: "k5 타이어 교체")
        XCTAssertLessThan(calculator.score(lhs, rhs), calculator.configuration.mergeThreshold)
    }
}
