//
//  SnapshotSupport.swift
//  ThemeKitTests
//
//  Shared configuration for the visual-regression (snapshot) suite.
//
//  Snapshots render real pixels, so they only run where SwiftUI rendering is
//  deterministic: a locally pinned iOS Simulator (iPhone 17 / iOS 26 — the
//  device the committed references were recorded on). They are opt-in and do
//  NOT run in CI. On macOS (`swift test`) this whole file compiles to nothing,
//  so the logic suite stays fast and host-independent.
//
//  Recording / running references is driven by RUN_SNAPSHOTS / RECORD_SNAPSHOTS
//  set on the ThemeKit-Package scheme's Test action (shell env vars do
//  not cross into the Simulator). Full instructions: docs/SNAPSHOT-TESTING.md.
//

#if canImport(UIKit)
import ThemeKit
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

/// Base class for the visual-regression suites. Centralises the opt-in gate so
/// every snapshot test skips unless `RUN_SNAPSHOTS=1` is set on the scheme's
/// Test action (see docs/SNAPSHOT-TESTING.md).
@MainActor
class SnapshotTestCase: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_SNAPSHOTS"] == "1",
            "Set RUN_SNAPSHOTS=1 (on the scheme's Test action) to run the visual-regression suite."
        )
    }
}

enum SnapshotConfig {
    /// Set `RECORD_SNAPSHOTS=1` in the environment to (re)generate references.
    static let isRecording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"

    /// Fraction of pixels that must match exactly (1.0 = identical). A hair of
    /// slack absorbs sub-pixel antialiasing noise between GPU/OS builds.
    static let precision: Float = 0.99

    /// Per-pixel perceptual closeness — absorbs gamma/AA differences without
    /// letting a real visual regression (color, layout, missing element) pass.
    static let perceptualPrecision: Float = 0.98

    /// Width every component renders at, mirroring an iPhone content column.
    static let defaultWidth: CGFloat = 390
}

/// Assert a component matches its recorded reference image.
///
/// The view is pinned to a fixed width and sized to fit its content, so the
/// snapshot is reproducible regardless of the host device. Pass a non-default
/// `contentSize` to prove a component scales under Dynamic Type.
@MainActor
func assertComponentSnapshot(
    _ view: some View,
    width: CGFloat = SnapshotConfig.defaultWidth,
    colorScheme: ColorScheme = .light,
    contentSize: UIContentSizeCategory = .large,
    layoutDirection: LayoutDirection = .leftToRight,
    named name: String? = nil,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    // Components read their palette from the Theme.shared singleton (imperative
    // isDark), NOT the SwiftUI colorScheme environment — so setting only
    // `.environment(\.colorScheme,)` would render the light palette on a dark
    // backdrop. Load the DEFAULT theme at the requested scheme to establish a
    // known baseline first (a sibling suite may have left a custom ThemeConfig in
    // the singleton), and reset to the clean default afterwards — together this
    // makes the suite fully order-independent.
    Theme.shared.loadTheme(named: Theme.defaultThemeName, dark: colorScheme == .dark)
    defer { Theme.shared.loadTheme(named: Theme.defaultThemeName, dark: false) }

    let traits = UITraitCollection { mutable in
        mutable.userInterfaceStyle = colorScheme == .dark ? .dark : .light
        mutable.preferredContentSizeCategory = contentSize
        mutable.layoutDirection = layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    let strategy = Snapshotting<AnyView, UIImage>.image(
        precision: SnapshotConfig.precision,
        perceptualPrecision: SnapshotConfig.perceptualPrecision,
        layout: .sizeThatFits,
        traits: traits
    )

    // Constrain width, let height be intrinsic, and tint the backdrop so any
    // transparent padding is visible in the diff rather than blending away.
    let wrapped = AnyView(
        view
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, colorScheme)
            .environment(\.layoutDirection, layoutDirection)
    )

    assertSnapshot(
        of: wrapped,
        as: strategy,
        named: name,
        record: SnapshotConfig.isRecording,
        file: file,
        testName: testName,
        line: line
    )
}
#endif
