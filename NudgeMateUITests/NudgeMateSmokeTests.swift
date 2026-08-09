import XCTest

final class NudgeMateSmokeTests: XCTestCase {
    func testFirstLaunchShowsOnboarding() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.otherElements["onboarding.screen"].waitForExistence(timeout: 5))
    }
}
