import XCTest

@MainActor
final class RooBinUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["ROOBIN_FORCE_EXPIRED_SESSION"] = "1"
        app.launch()
    }

    func testSignedOutWelcomeOffersAllSupportedMethods() {
        XCTAssertTrue(app.buttons["auth.apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["auth.google"].exists)
        XCTAssertTrue(app.buttons["auth.email"].exists)
        XCTAssertTrue(app.staticTexts["auth.legalNotice"].exists)
    }

    func testEmailJourneyCanOpenAndReturnWithoutNetworkRequest() {
        let emailButton = app.buttons["auth.email"]
        XCTAssertTrue(emailButton.waitForExistence(timeout: 5))
        emailButton.tap()

        XCTAssertTrue(app.textFields["auth.email.address"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["auth.email.submit"].isEnabled)

        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["auth.email"].waitForExistence(timeout: 2))
    }

    func testUnconfiguredProviderExplainsEmailFallback() {
        let googleButton = app.buttons["auth.google"]
        XCTAssertTrue(googleButton.waitForExistence(timeout: 5))
        googleButton.tap()

        XCTAssertTrue(app.alerts["Google sign-in"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.alerts["Google sign-in"].staticTexts[
                "Provider configuration is pending. Email remains the universal fallback."
            ].exists
        )
    }
}
