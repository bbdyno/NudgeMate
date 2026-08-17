import XCTest

final class NudgeMateSmokeTests: XCTestCase {
    func testFirstLaunchShowsOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-onboarding"]
        app.launch()
        XCTAssertTrue(app.scrollViews["onboarding.screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.scan"].exists)
        XCTAssertTrue(app.buttons["onboarding.manual"].exists)
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

    func testCentralQuickAddOffersScheduleAndPrep() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let quickCapture = app.buttons["main.quickAdd"]
        XCTAssertTrue(quickCapture.waitForExistence(timeout: 5))
        XCTAssertTrue(quickCapture.isHittable)
        quickCapture.tap()

        let calendarAction = app.buttons["quickAdd.calendar"]
        let prepAction = app.buttons["quickAdd.prep"]
        XCTAssertTrue(calendarAction.waitForExistence(timeout: 3))
        XCTAssertTrue(prepAction.waitForExistence(timeout: 3))
        XCTAssertTrue(calendarAction.isHittable)
        XCTAssertTrue(prepAction.isHittable)

        calendarAction.tap()
        XCTAssertTrue(app.otherElements["calendar.composer.screen"].waitForExistence(timeout: 3))
    }

    func testMoreTabOpensMoreScreen() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let moreTab = app.buttons["main.tab.more"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 5))
        XCTAssertTrue(moreTab.isHittable)
        moreTab.tap()

        XCTAssertTrue(app.buttons["more.settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(moreTab.isSelected)
    }

    func testTodayPrepCardOpensEditor() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let prepCard = app.descendants(matching: .any)["home.prep.card"].firstMatch
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
        let lastAction = actions.element(boundBy: 1)
        let tabBar = app.otherElements["main.tabbar"]
        XCTAssertTrue(tabBar.waitForExistence(timeout: 2))
        var attempts = 0
        while (
            !lastAction.isHittable
                || lastAction.frame.maxY > tabBar.frame.minY
        ) && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(lastAction.isHittable)
        XCTAssertLessThanOrEqual(
            lastAction.frame.maxY,
            tabBar.frame.minY,
            "The final nudge action must scroll fully above the custom tab bar."
        )
        lastAction.tap()
        XCTAssertTrue(app.buttons["nudge.skip"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["nudge.toggleMute"].exists)
        XCTAssertTrue(app.buttons["nudge.delete"].exists)
    }

    func testTodaySummaryAndTurningOffRhythmStayInSync() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let summary = app.descendants(matching: .any)["home.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.value as? String, "6")
        XCTAssertTrue(app.descendants(matching: .any)["home.priority"].exists)

        let actions = app.buttons.matching(identifier: "nudge.moreActions").firstMatch
        var attempts = 0
        while (!actions.exists || !actions.isHittable) && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(actions.isHittable)
        actions.tap()

        let turnOff = app.buttons["nudge.toggleMute"]
        XCTAssertTrue(turnOff.waitForExistence(timeout: 2))
        turnOff.tap()

        let summaryUpdated = NSPredicate { evaluated, _ in
            (evaluated as? XCUIElement)?.value as? String == "5"
        }
        expectation(for: summaryUpdated, evaluatedWith: summary)
        waitForExpectations(timeout: 3)
    }

    func testTodayRhythmViewAllOpensRhythmList() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let viewAll = app.buttons["home.rhythms.viewAll"]
        var attempts = 0
        while (!viewAll.exists || !viewAll.isHittable) && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(viewAll.isHittable)
        viewAll.tap()

        XCTAssertTrue(app.scrollViews["rhythm.list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["main.tab.rhythms"].isSelected)
    }

    func testTodayCanDeleteRhythmFromItsMenu() {
        let app = seededApp(opening: "--open-today")
        app.launch()

        let summary = app.descendants(matching: .any)["home.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.value as? String, "6")

        let actions = app.buttons.matching(identifier: "nudge.moreActions").firstMatch
        var attempts = 0
        while (!actions.exists || !actions.isHittable) && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(actions.isHittable)
        actions.tap()

        let delete = app.buttons["nudge.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 2))
        delete.tap()
        let confirmDelete = app.buttons.matching(identifier: "nudge.confirmDelete").firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 2))
        confirmDelete.tap()

        let summaryUpdated = NSPredicate { evaluated, _ in
            (evaluated as? XCUIElement)?.value as? String == "5"
        }
        expectation(for: summaryUpdated, evaluatedWith: summary)
        waitForExpectations(timeout: 3)
    }

    func testRhythmListSupportsSelectAll() {
        let app = seededApp(opening: "--open-rhythms")
        app.launch()

        XCTAssertTrue(app.scrollViews["rhythm.list"].waitForExistence(timeout: 5))
        assertCompactIconAction(app.buttons["selection.start"])
        assertCompactIconAction(app.buttons["screen.add"])
        assertCompactIconAction(app.buttons["rhythm.card.moreActions"].firstMatch)
        app.buttons["selection.start"].tap()
        app.buttons["selection.toggleAll"].tap()

        let count = app.staticTexts["selection.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 2))
        XCTAssertTrue(count.label.contains("4"))
        XCTAssertTrue(app.buttons["selection.delete"].isEnabled)
        let tabBar = app.otherElements["main.tabbar"]
        XCTAssertTrue(tabBar.waitForExistence(timeout: 2))
        XCTAssertLessThanOrEqual(
            app.buttons["selection.delete"].frame.maxY,
            tabBar.frame.minY,
            "The bulk action bar must stay above the custom tab bar."
        )
        app.buttons["selection.delete"].tap()
        XCTAssertTrue(app.buttons["selection.confirmDelete"].waitForExistence(timeout: 2))
    }

    func testPrepListUsesSeededCards() {
        let app = seededApp(opening: "--open-prep")
        app.launch()

        XCTAssertTrue(app.scrollViews["prep.list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["selection.start"].exists)
        assertCompactIconAction(app.buttons["selection.start"])
        assertCompactIconAction(app.buttons["screen.add"])
        assertCompactIconAction(app.buttons["prep.card.moreActions"].firstMatch)
        let tabBar = app.otherElements["main.tabbar"]
        XCTAssertTrue(tabBar.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["main.tab.today"].exists)
        XCTAssertTrue(app.buttons["main.tab.rhythms"].exists)
        XCTAssertTrue(app.buttons["main.tab.prep"].isSelected)
        XCTAssertTrue(app.buttons["main.tab.more"].exists)
        XCTAssertTrue(app.buttons["main.quickAdd"].exists)

        app.buttons["selection.start"].tap()
        app.buttons["selection.toggleAll"].tap()
        XCTAssertLessThanOrEqual(
            app.buttons["selection.delete"].frame.maxY,
            tabBar.frame.minY + 2,
            "The prep bulk action bar must stay above the native tab bar."
        )
    }

    func testPrepHeaderAndStatusControlsShareAlignmentGrid() {
        let app = seededApp(opening: "--open-prep")
        app.launch()

        let title = app.staticTexts["screen.title"]
        let subtitle = app.staticTexts["screen.subtitle"]
        let itemCount = app.staticTexts["screen.itemCount"]
        let select = app.buttons["selection.start"]
        let add = app.buttons["screen.add"]

        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(subtitle.exists)
        XCTAssertTrue(itemCount.exists)
        XCTAssertEqual(title.frame.midY, itemCount.frame.midY, accuracy: 2)
        XCTAssertEqual(title.frame.minX, subtitle.frame.minX, accuracy: 1)
        XCTAssertEqual(select.frame.midY, add.frame.midY, accuracy: 1)
        XCTAssertEqual(select.frame.width, add.frame.width, accuracy: 1)
        XCTAssertEqual(select.frame.height, add.frame.height, accuracy: 1)

        let firstStatusRow = [
            app.descendants(matching: .any)["prep.status.notReady"].firstMatch,
            app.descendants(matching: .any)["prep.status.inProgress"].firstMatch,
            app.descendants(matching: .any)["prep.status.ready"].firstMatch
        ]
        for button in firstStatusRow {
            XCTAssertTrue(button.waitForExistence(timeout: 2))
        }
        XCTAssertEqual(firstStatusRow[0].frame.midY, firstStatusRow[1].frame.midY, accuracy: 1)
        XCTAssertEqual(firstStatusRow[1].frame.midY, firstStatusRow[2].frame.midY, accuracy: 1)
        XCTAssertEqual(firstStatusRow[0].frame.width, firstStatusRow[1].frame.width, accuracy: 1)
        XCTAssertEqual(firstStatusRow[1].frame.width, firstStatusRow[2].frame.width, accuracy: 1)
    }

    private func seededApp(opening tabArgument: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--seed-content", tabArgument]
        return app
    }

    private func assertCompactIconAction(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.width, 43.5, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.height, 43.5, file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.width, 52, file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.height, 52, file: file, line: line)
    }
}
