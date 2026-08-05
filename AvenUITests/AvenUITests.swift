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
        XCTAssertTrue(app.staticTexts["onboarding.welcome.title"].exists)
        XCTAssertTrue(app.otherElements["onboarding.screen.welcome"].exists)
        XCTAssertTrue(app.otherElements["onboarding.welcome.cube"].exists)
        XCTAssertFalse(app.staticTexts["onboarding.wordmark"].exists)
        XCTAssertFalse(app.buttons["onboarding.back"].exists)
        XCTAssertFalse(app.staticTexts["onboarding.progress.accessibility"].exists)
        XCTAssertFalse(app.progressIndicators["onboarding.progress.accessibility"].exists)

        continueButton.tap()

        XCTAssertTrue(
            app.otherElements["onboarding.screen.privacy"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["onboarding.wordmark"].exists)
        XCTAssertTrue(app.buttons["onboarding.back"].exists)
        continueButton.tap()

        XCTAssertTrue(app.textFields["onboarding.name"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["onboarding.back"].exists)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", ".*[0-9]+[ ]*(of|/)[ ]*[0-9]+.*")
        ).firstMatch.exists)
    }

    func testCompleteOnboardingJourneyReachesTheApp() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing-onboarding",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_GB"
        ]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 8))
        continueButton.tap()
        XCTAssertTrue(
            app.otherElements["onboarding.screen.privacy"].waitForExistence(timeout: 5)
        )
        continueButton.tap()

        let nameField = app.textFields["onboarding.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Oksana")
        continueButton.tap()

        XCTAssertTrue(
            app.datePickers["onboarding.birth-date"].waitForExistence(timeout: 3)
        )
        continueButton.tap()

        let gender = app.buttons["onboarding.gender.female"]
        XCTAssertTrue(gender.waitForExistence(timeout: 3))
        gender.tap()
        continueButton.tap()

        XCTAssertTrue(
            app.buttons["onboarding.country.gb"].waitForExistence(timeout: 3)
        )
        continueButton.tap()

        XCTAssertTrue(
            app.buttons["onboarding.relationship.dating"].waitForExistence(timeout: 3)
        )
        continueButton.tap()

        XCTAssertTrue(
            app.datePickers["onboarding.relationship-date"].waitForExistence(timeout: 3)
        )
        continueButton.tap()

        XCTAssertTrue(
            app.buttons["onboarding.notifications.skip"].waitForExistence(timeout: 3)
        )
        continueButton.tap()

        XCTAssertTrue(
            app.buttons["onboarding.location.skip"].waitForExistence(timeout: 3)
        )
        continueButton.tap()

        let skipAI = app.buttons["onboarding.ai.skip"]
        XCTAssertTrue(skipAI.waitForExistence(timeout: 3))
        skipAI.tap()
        continueButton.tap()

        XCTAssertTrue(
            app.otherElements["pairing.connected"].waitForExistence(timeout: 5)
        )
        continueButton.tap()

        XCTAssertTrue(
            app.staticTexts["Made for mutual care"].waitForExistence(timeout: 3)
        )
        continueButton.tap()

        XCTAssertTrue(app.tabBars.buttons["tab.home"].waitForExistence(timeout: 5))
    }
}
