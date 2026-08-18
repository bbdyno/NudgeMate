import XCTest
@testable import NudgeMate

final class InterstitialAdEligibilityPolicyTests: XCTestCase {
    private let policy = InterstitialAdEligibilityPolicy()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFreeUserWithConsentAndNoPriorImpressionIsEligible() {
        XCTAssertEqual(
            policy.evaluate(
                isPro: false,
                canRequestAds: true,
                lastPresentedAt: nil,
                now: now
            ),
            .eligible
        )
    }

    func testProUserIsNeverEligible() {
        XCTAssertEqual(
            policy.evaluate(
                isPro: true,
                canRequestAds: true,
                lastPresentedAt: nil,
                now: now
            ),
            .proUser
        )
    }

    func testConsentMustAllowAdRequests() {
        XCTAssertEqual(
            policy.evaluate(
                isPro: false,
                canRequestAds: false,
                lastPresentedAt: nil,
                now: now
            ),
            .consentRequired
        )
    }

    func testImpressionWithinTwentyFourHoursIsCoolingDown() {
        let lastPresentedAt = now.addingTimeInterval(-60 * 60)
        XCTAssertEqual(
            policy.evaluate(
                isPro: false,
                canRequestAds: true,
                lastPresentedAt: lastPresentedAt,
                now: now
            ),
            .coolingDown(
                until: lastPresentedAt.addingTimeInterval(
                    InterstitialAdEligibilityPolicy.cooldown
                )
            )
        )
    }

    func testImpressionAtLeastTwentyFourHoursAgoIsEligible() {
        XCTAssertEqual(
            policy.evaluate(
                isPro: false,
                canRequestAds: true,
                lastPresentedAt: now.addingTimeInterval(
                    -InterstitialAdEligibilityPolicy.cooldown
                ),
                now: now
            ),
            .eligible
        )
    }

    func testDebugBuildUsesGoogleTestInterstitial() {
        XCTAssertEqual(
            AdMobConfiguration.interstitialAdUnitID,
            AdMobConfiguration.testInterstitialAdUnitID
        )
    }

    func testAdMobIdentifiersMatchConfiguredConsoleResources() {
        XCTAssertEqual(
            AdMobConfiguration.applicationID,
            "ca-app-pub-8965771939775493~6712972291"
        )
        XCTAssertEqual(
            AdMobConfiguration.productionInterstitialAdUnitID,
            "ca-app-pub-8965771939775493/7478475235"
        )
    }
}
