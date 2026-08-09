import XCTest
@testable import NudgeMate

final class EntitlementPolicyTests: XCTestCase {
    private let policy = EntitlementPolicy()

    func testFreeUserCanCreateThreeAdaptiveRhythms() {
        XCTAssertEqual(
            policy.adaptiveRhythmCreation(activeAdaptiveCount: 2, isPro: false),
            .allowed
        )
    }

    func testFourthAdaptiveRhythmRequiresPro() {
        XCTAssertEqual(
            policy.adaptiveRhythmCreation(activeAdaptiveCount: 3, isPro: false),
            .requiresPro
        )
    }

    func testSecondActivePrepRequiresPro() {
        XCTAssertEqual(
            policy.prepCreation(activePrepCount: 1, isPro: false),
            .requiresPro
        )
    }

    func testProHasUnlimitedAccess() {
        XCTAssertEqual(
            policy.adaptiveRhythmCreation(activeAdaptiveCount: 100, isPro: true),
            .allowed
        )
        XCTAssertEqual(
            policy.prepCreation(activePrepCount: 100, isPro: true),
            .allowed
        )
    }
}
