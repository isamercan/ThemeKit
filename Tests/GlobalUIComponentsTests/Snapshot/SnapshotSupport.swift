//
//  SnapshotSupport.swift
//  GlobalUIComponentsTests
//
//  Shared configuration for the visual-regression (snapshot) suite.
//
//  Snapshots render real pixels, so they only run where SwiftUI rendering is
//  deterministic: the pinned iOS Simulator used by the `ios` CI job. On macOS
//  (`swift test`) this whole file compiles to nothing, so the logic suite stays
//  fast and host-independent.
//
//  Recording references:
//    RECORD_SNAPSHOTS=1 xcodebuild test -scheme GlobalUIComponents \
//      -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2'
//  Then commit the generated __Snapshots__ folders. Re-run without the flag to
//  verify they pass.
//

#if canImport(UIKit)
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
