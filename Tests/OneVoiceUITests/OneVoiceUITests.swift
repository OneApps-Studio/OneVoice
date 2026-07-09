import XCTest

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
        XCTAssertTrue(app.staticTexts["音频和转写内容仅保存在此设备"].exists)
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
