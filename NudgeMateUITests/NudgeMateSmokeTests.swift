import XCTest

final class NudgeMateSmokeTests: XCTestCase {
    func testFirstLaunchShowsOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-onboarding"]
        app.launch()
        XCTAssertTrue(app.otherElements["onboarding.screen"].waitForExistence(timeout: 5))
    }

    func testTodayShowsARecognizableSettingsControl() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let settingsButton = app.buttons["home.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsButton.isHittable)
        XCTAssertGreaterThanOrEqual(settingsButton.frame.width, 35.5)
        XCTAssertGreaterThanOrEqual(settingsButton.frame.height, 35.5)
    }

    func testTodayQuickCaptureOpensScheduleReview() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let quickCapture = app.buttons["home.quickCapture"]
        XCTAssertTrue(quickCapture.waitForExistence(timeout: 5))
        XCTAssertTrue(quickCapture.isHittable)
        quickCapture.tap()

        XCTAssertTrue(
            app.otherElements["calendar.composer.screen"].waitForExistence(timeout: 3)
                || app.textFields["calendar.composer.title"].waitForExistence(timeout: 3)
        )
    }

    func testTodayPrepCardOpensEditor() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let prepCard = app.buttons["home.prep.card"].firstMatch
        XCTAssertTrue(prepCard.waitForExistence(timeout: 5))
        XCTAssertTrue(prepCard.isHittable)
        prepCard.tap()

        XCTAssertTrue(app.otherElements["prep.editor.screen"].waitForExistence(timeout: 3))
    }

    func testTodayLastNudgeActionsCanScrollAboveTabBar() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let actions = app.buttons.matching(identifier: "nudge.moreActions")
        XCTAssertTrue(actions.firstMatch.waitForExistence(timeout: 5))
        let lastAction = actions.element(boundBy: 2)
        var attempts = 0
        while !lastAction.isHittable && attempts < 4 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(lastAction.isHittable)
        XCTAssertLessThanOrEqual(
            lastAction.frame.maxY,
            app.tabBars.firstMatch.frame.minY,
            "The final nudge action must scroll fully above the floating tab bar."
        )
        lastAction.tap()
        XCTAssertTrue(app.buttons["nudge.skip"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["nudge.toggleMute"].exists)
    }

    func testRhythmListSupportsSelectAll() {
        let app = seededApp(opening: "--open-rhythms")
        app.launch()

        XCTAssertTrue(app.scrollViews["rhythm.list"].waitForExistence(timeout: 5))
        app.buttons["selection.start"].tap()
        app.buttons["selection.toggleAll"].tap()

        let count = app.staticTexts["selection.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 2))
        XCTAssertTrue(count.label.contains("4"))
        XCTAssertTrue(app.buttons["selection.delete"].isEnabled)
        XCTAssertLessThanOrEqual(
            app.buttons["selection.delete"].frame.maxY,
            app.tabBars.firstMatch.frame.minY,
            "The bulk action bar must stay above the native tab bar."
        )
        app.buttons["selection.delete"].tap()
        XCTAssertTrue(app.buttons["selection.confirmDelete"].waitForExistence(timeout: 2))
    }

    func testPrepListUsesSeededCards() {
        let app = seededApp(opening: "--open-prep")
        app.launch()

        XCTAssertTrue(app.scrollViews["prep.list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["selection.start"].exists)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 2))
        XCTAssertEqual(tabBar.buttons.count, 3)
        XCTAssertTrue(tabBar.buttons.element(boundBy: 2).isSelected)

        app.buttons["selection.start"].tap()
        app.buttons["selection.toggleAll"].tap()
        XCTAssertLessThanOrEqual(
            app.buttons["selection.delete"].frame.maxY,
            tabBar.frame.minY,
            "The prep bulk action bar must stay above the native tab bar."
        )
    }

    private func seededApp(opening tabArgument: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--seed-content", tabArgument]
        return app
    }
}
