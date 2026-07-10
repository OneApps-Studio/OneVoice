import XCTest

final class SidebarNavigationTests: XCTestCase {
    @MainActor
    func testEverySidebarDestinationCanBeSelected() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--onevoice-ui-testing"]
        app.launch()

        try assertSelecting("Dictionary", in: app)
        try assertSelecting("Models", in: app)
        try assertSelecting("Setup", in: app)
        try assertSelecting("Library", in: app)
    }

    @MainActor
    func testDictionaryCanAddAndDeleteReplacement() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--onevoice-ui-testing"]
        app.launch()
        try assertSelecting("Dictionary", in: app)

        let source = "ovtmp"
        let replacement = "OVTMP"
        let fields = app.textFields
        XCTAssertEqual(fields.count, 2)

        fields.element(boundBy: 0).click()
        fields.element(boundBy: 0).typeText(source)
        fields.element(boundBy: 1).click()
        fields.element(boundBy: 1).typeText(replacement)
        app.buttons["Add Replacement"].click()

        let addedSource = app.staticTexts.matching(
            NSPredicate(format: "value == %@", source)
        ).firstMatch
        XCTAssertTrue(addedSource.waitForExistence(timeout: 2))
        let deleteButtons = app.buttons.matching(
            NSPredicate(format: "label == 'Delete'")
        )
        XCTAssertGreaterThan(deleteButtons.count, 0)
        deleteButtons.element(boundBy: deleteButtons.count - 1).click()
        XCTAssertFalse(addedSource.waitForExistence(timeout: 1))
    }

    @MainActor
    func testModelsAndSetupExposeOperationalControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--onevoice-ui-testing"]
        app.launch()

        try assertSelecting("Models", in: app)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "value == 'Apple On-Device Speech'")
        ).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "value == 'Qwen3-ASR 0.6B'")
        ).firstMatch.exists)

        try assertSelecting("Setup", in: app)
        XCTAssertTrue(app.buttons["Grant Required Permissions"].exists)
        XCTAssertTrue(app.buttons["Open Privacy & Security"].exists)
    }

    @MainActor
    private func assertSelecting(_ title: String, in app: XCUIApplication) throws {
        let labels = app.staticTexts.matching(
            NSPredicate(format: "value == %@", title)
        )
        let sidebarItem = labels.firstMatch
        XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5), "Missing sidebar item: \(title)")
        sidebarItem.click()
        let destinationLoaded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "title == %@", title),
            object: app.windows.firstMatch
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [destinationLoaded], timeout: 2),
            .completed,
            "Selecting \(title) did not change the window destination"
        )
    }
}
