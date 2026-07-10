import XCTest

@MainActor
final class OneVoiceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingExplainsTheOfflineWorkflow() {
        let app = launchApp(onboardingCompleted: false)

        XCTAssertTrue(app.staticTexts["Your Voice Stays Yours"].waitForExistence(timeout: 8))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Fast Live, Accurate Final"].waitForExistence(timeout: 3))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Speak, Save, Share"].waitForExistence(timeout: 3))
        app.buttons["Start"].tap()
        XCTAssertTrue(app.tabBars.buttons["Record"].waitForExistence(timeout: 5))
    }

    func testMainTabsAndDictionaryWorkflow() {
        let app = launchApp(onboardingCompleted: true)

        XCTAssertTrue(app.tabBars.buttons["Record"].waitForExistence(timeout: 8))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No voice notes yet"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Dictionary"].tap()
        let spoken = app.textFields["What OneVoice hears"]
        let written = app.textFields["What OneVoice should write"]
        XCTAssertTrue(spoken.waitForExistence(timeout: 3))
        spoken.tap()
        spoken.typeText("one voice")
        written.tap()
        written.typeText("OneVoice")
        app.buttons["Add Replacement"].tap()
        XCTAssertTrue(app.staticTexts["OneVoice"].waitForExistence(timeout: 3))
    }

    func testSimplifiedChineseSettingsAreLocalized() {
        let app = launchApp(
            onboardingCompleted: true,
            language: "simplifiedChinese",
            initialTab: "settings"
        )

        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["语音识别"].exists)
        XCTAssertTrue(app.staticTexts["高精度模型"].exists)
        XCTAssertTrue(app.staticTexts["你的录音保持私密"].exists)
    }

    func testRecordingContinuesAfterBackgrounding() throws {
        guard ProcessInfo.processInfo.environment["ONEVOICE_RUN_BACKGROUND_TEST"] == "1" else {
            throw XCTSkip("Run on a physical device with ONEVOICE_RUN_BACKGROUND_TEST=1.")
        }

        addUIInterruptionMonitor(withDescription: "Recording permissions") { alert in
            for title in ["Allow", "允许", "好", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }

        let app = launchApp(onboardingCompleted: true)
        let recordButton = app.buttons["record-button"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 12))
        recordButton.tap()
        app.tap()
        XCTAssertTrue(app.buttons["Finish recording"].waitForExistence(timeout: 15))

        XCUIDevice.shared.press(.home)
        sleep(5)
        app.activate()

        XCTAssertTrue(app.buttons["Finish recording"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["00:00"].exists)
        app.buttons["Finish recording"].tap()

        if app.alerts.firstMatch.waitForExistence(timeout: 12) {
            app.alerts.firstMatch.buttons["OK"].tap()
        }
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 20))
        app.tabBars.buttons["History"].tap()
        XCTAssertGreaterThan(app.cells.count, 0)
    }

    private func launchApp(
        onboardingCompleted: Bool,
        language: String = "english",
        initialTab: String = "record"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ONEVOICE_UI_TEST", "1",
            "-ONEVOICE_RESET_DATA", "1",
            "-ONEVOICE_HAS_COMPLETED_ONBOARDING", onboardingCompleted ? "1" : "0",
            "-ONEVOICE_APP_LANGUAGE", language,
            "-ONEVOICE_INITIAL_TAB", initialTab,
        ]
        app.launch()
        return app
    }
}
