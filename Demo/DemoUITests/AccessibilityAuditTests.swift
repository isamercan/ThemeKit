//
//  AccessibilityAuditTests.swift
//  DemoUITests
//
//  Automated accessibility auditing via `XCUIApplication.performAccessibilityAudit()`
//  (iOS 17+) — catches contrast, dynamic-type clipping, element description, hit-region
//  and trait issues that the unit-level a11y tests can't. Drives the gallery and
//  representative component pages through the Demo app's `-openDemo` deep-link.
//
//  SETUP: this file needs a UI-testing target in Demo.xcodeproj (one-time, see
//  docs/ACCESSIBILITY-AUDIT.md). Once wired, run with ⌘U or:
//    xcodebuild test -project Demo/Demo.xcodeproj -scheme DemoUITests \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
//

import XCTest

final class AccessibilityAuditTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true   // report every screen's issues, don't stop at the first
    }

    /// Launches the Demo, optionally deep-linked to a gallery page, and audits it.
    @MainActor
    private func audit(openDemo page: String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
        let app = XCUIApplication()
        if let page { app.launchArguments += ["-openDemo", page] }
        app.launch()

        // Audit every category. Add an issue handler here to triage known,
        // intentional exceptions (return `true` to ignore) once a baseline is set.
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testComponentGalleryIsAccessible() throws {
        try audit()
    }

    @MainActor
    func testThemeInjectionPageIsAccessible() throws {
        try audit(openDemo: "Theme Injection")
    }

    // Representative, interaction-heavy components across the three layers.
    @MainActor func testTextInputFormIsAccessible() throws { try audit(openDemo: "Form") }
    @MainActor func testSelectIsAccessible() throws { try audit(openDemo: "Select") }
    @MainActor func testDataTableIsAccessible() throws { try audit(openDemo: "DataTable") }
    @MainActor func testStepsIsAccessible() throws { try audit(openDemo: "Steps") }
}
