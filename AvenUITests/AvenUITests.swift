import XCTest

@MainActor
final class AvenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEnglishWelcomeAndRealSignInEntryPointsAreVisible() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()

        XCTAssertTrue(app.staticTexts["auth.welcome.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["auth.apple"].exists)
        XCTAssertTrue(app.buttons["auth.google"].exists)
        XCTAssertTrue(app.buttons["auth.guest"].exists)
        XCTAssertFalse(app.buttons["auth.demo"].exists)
        XCTAssertFalse(app.buttons["auth.language"].exists)
    }

    func testAuthenticatedShellCanSendMessage() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-authenticated",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        let messagesTab = app.tabBars.buttons["tab.messages"]
        XCTAssertTrue(messagesTab.waitForExistence(timeout: 5))
        messagesTab.tap()

        let composer = app.textFields["messages.composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Hello from UI testing")
        app.buttons["messages.send"].tap()

        XCTAssertTrue(app.staticTexts["Hello from UI testing"].exists)
    }

    func testSimulatorGuestSignInContinuesWithoutFirebase() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-guest-sign-in",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        let guestButton = app.buttons["auth.guest"]
        XCTAssertTrue(guestButton.waitForExistence(timeout: 5))
        guestButton.tap()

        XCTAssertTrue(
            app.otherElements["pairing.connected"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["onboarding.continue"].exists)
    }

    func testPremiumOnboardingHidesProgressAndShowsFocusedNameStep() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-onboarding",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["onboarding.wordmark"].exists)
        XCTAssertFalse(app.staticTexts["onboarding.progress.accessibility"].exists)
        XCTAssertFalse(app.progressIndicators["onboarding.progress.accessibility"].exists)

        continueButton.tap()

        XCTAssertTrue(app.textFields["onboarding.name"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["onboarding.back"].exists)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", ".*[0-9]+[ ]*(of|/)[ ]*[0-9]+.*")
        ).firstMatch.exists)
    }
}
