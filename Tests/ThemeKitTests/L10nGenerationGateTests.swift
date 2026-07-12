//
//  L10nGenerationGateTests.swift
//  ThemeKit
//
//  ADR-0003 §D7 — the CI drift gate. Runs `tools/gen_l10n.py --check`, which
//  regenerates the catalogs + consumer template + key-invariant test in
//  memory and fails on ANY difference from disk, and independently asserts
//  that every `String(themeKit:)` / `String(themeKitTravel:)` key extracted
//  from source exists in its on-disk catalog. This is the "no missing
//  key-value" guarantee: an English copy edit or a new call site surfaces as
//  a red build here (fix: `make l10n`), never as a silently orphaned
//  consumer translation.
//
//  macOS-only: it spawns python3 (the spm-macos CI lane runs it; the iOS
//  simulator lane compiles it out).
//

#if os(macOS)
import XCTest

final class L10nGenerationGateTests: XCTestCase {
    func testL10nArtifactsAreInSyncWithSource() throws {
        var root = URL(fileURLWithPath: #filePath)
        while root.path != "/" {
            root.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
                break
            }
        }
        let script = root.appendingPathComponent("tools/gen_l10n.py")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: script.path),
                          "source checkout not available (installed-package test run)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", script.path, "--check"]
        process.currentDirectoryURL = root
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0, """
            Localization artifacts drifted from source — run `make l10n` and commit.
            \(output)
            """)
    }
}
#endif
