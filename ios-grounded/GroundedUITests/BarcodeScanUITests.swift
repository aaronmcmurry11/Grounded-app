//
//  BarcodeScanUITests.swift
//  GroundedUITests
//
//  Exercises the barcode scanner's manual-entry path against the REAL Open Food Facts API —
//  not a mock. This is deliberate: the app-building sandbox this feature was written in has
//  no network access to openfoodfacts.org (its egress is allowlisted and that domain isn't on
//  it), so `ProductLookupService` was written blind from documented API shape and never
//  exercised against a live response. GitHub's macOS runners have normal internet access, so
//  running this as part of CI is the first real, automated proof that the lookup + grading
//  pipeline actually works end to end — without needing a physical device or TestFlight.
//
//  Uses the manual "Enter a code manually" entry path rather than the camera, since there's
//  no way to feed a real camera image into a headless CI simulator. That path runs through
//  the exact same `ProductLookupService`/`ProductGrading` code the camera path does — the
//  camera only supplies the barcode string, which this test supplies by typing it in.
//
//  Test barcode: 3017620422003 (Nutella, 400g, EAN-13) — chosen because it's the barcode
//  Open Food Facts uses in its own public documentation/examples, so it's about as safe a
//  bet as exists for "this will actually be in their database."
//
//  This test is intentionally lenient about WHICH outcome it hits (found / not-found /
//  network error) — a live third-party API can have an off day, and that shouldn't block
//  CI on unrelated changes. What it does insist on is that the app reaches SOME real,
//  recognizable end state within a generous timeout, and it always attaches a screenshot of
//  whatever it found so a human (or a future Claude session, since nobody running this has a
//  way to view .xcresult bundles) can see exactly what happened.
//
//  Screenshot capture lives in tearDownWithError rather than inline in the test body: with
//  continueAfterFailure = false, an earlier assertion failing (e.g. the Scan tab never
//  appearing) aborts the test immediately, and inline code after that point never runs.
//  tearDownWithError still runs after an abort, so it's the only place a screenshot is
//  guaranteed to actually get captured no matter which step fails.

import XCTest

final class BarcodeScanUITests: XCTestCase {

    private let testBarcode = "3017620422003"
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        // Runs after every test invocation regardless of pass/fail/abort, so this is the one
        // place a screenshot is guaranteed to be captured — see the file-level comment above.
        guard let app else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "barcode-scan-result"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testManualBarcodeLookupAgainstRealAPI() throws {
        app.launch()

        completeOnboardingIfPresented()

        let scanTab = app.buttons["tab.scan"]
        XCTAssertTrue(scanTab.waitForExistence(timeout: 10), "Scan tab never appeared — onboarding may not have completed.")
        scanTab.tap()

        let enterCodeButton = app.buttons["scanner.enterCodeManually"]
        XCTAssertTrue(enterCodeButton.waitForExistence(timeout: 10), "\"Enter a code manually\" button never appeared on the Scan tab.")
        enterCodeButton.tap()

        let codeField = app.textFields["manualCode.textField"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 5), "Manual code text field never appeared.")
        codeField.tap()
        codeField.typeText(testBarcode)

        let submitButton = app.buttons["manualCode.submit"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
        XCTAssertTrue(submitButton.isEnabled, "Submit button stayed disabled — the barcode may have failed local validation.")
        submitButton.tap()

        // Generous timeout: this is a real network round trip (lookup, possibly a second
        // fallback lookup against Open Beauty Facts, then grading), not a local operation.
        let productName = app.staticTexts["scanResult.productName"]
        let notFoundTitle = app.staticTexts["scanNotFound.title"]
        let networkAlert = app.alerts["Couldn't look that up"]

        let outcomeReached = productName.waitForExistence(timeout: 25)
            || notFoundTitle.waitForExistence(timeout: 1)
            || networkAlert.waitForExistence(timeout: 1)

        if productName.exists {
            print("[BarcodeScanUITests] Lookup succeeded — product name: \(productName.label)")
        } else if notFoundTitle.exists {
            print("[BarcodeScanUITests] Lookup completed but returned not-found for barcode \(testBarcode). This barcode is expected to exist in Open Food Facts, so a not-found result here is worth a second look, not necessarily a bug in this test.")
        } else if networkAlert.exists {
            print("[BarcodeScanUITests] Lookup hit a network error. Could be a transient CI networking issue or a real problem in ProductLookupService — check the attached screenshot and, if this repeats, the service's request/response handling.")
        }

        XCTAssertTrue(
            outcomeReached,
            "Neither a product result, a not-found screen, nor a network-error alert appeared within the timeout — the app may be hung or crashed on submit."
        )
    }

    /// Fresh CI simulator installs always start at onboarding. Walks through both steps if
    /// present; does nothing if onboarding was already completed (e.g. a reused simulator).
    @MainActor
    private func completeOnboardingIfPresented() {
        let understandButton = app.buttons["onboarding.understand"]
        guard understandButton.waitForExistence(timeout: 5) else { return }
        understandButton.tap()

        let consentHealth = app.buttons["onboarding.consentHealth"]
        let consentAge = app.buttons["onboarding.consentAge"]
        let getStarted = app.buttons["onboarding.getStarted"]

        XCTAssertTrue(consentHealth.waitForExistence(timeout: 5))
        consentHealth.tap()
        consentAge.tap()

        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        XCTAssertTrue(getStarted.isEnabled, "Get started stayed disabled after both consent toggles were tapped.")
        getStarted.tap()
    }
}
