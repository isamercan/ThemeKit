//
//  InfoMessageTests.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The pure InfoMessage value layer: severity ordering, dominant-kind selection,
//  icon resolution, and custom-icon override.
//

import XCTest
@testable import ThemeKit

final class InfoMessageTests: XCTestCase {

    func testKindSeverityOrdering() {
        XCTAssertTrue(InfoMessage.Kind.info < .success)
        XCTAssertTrue(InfoMessage.Kind.success < .warning)
        XCTAssertTrue(InfoMessage.Kind.warning < .error)
        XCTAssertEqual([InfoMessage.Kind.error, .info, .warning].max(), .error)
    }

    func testDominantKindPicksHighestSeverity() {
        let msgs = [InfoMessage("a", kind: .info),
                    InfoMessage("b", kind: .error),
                    InfoMessage("c", kind: .warning)]
        XCTAssertEqual(msgs.dominantKind, .error)
        XCTAssertEqual([InfoMessage("only", kind: .success)].dominantKind, .success)
        XCTAssertNil([InfoMessage]().dominantKind)
    }

    func testDefaultIconsPerSeverity() {
        XCTAssertNil(InfoMessage.Kind.info.systemImage)                 // info has no icon
        XCTAssertEqual(InfoMessage.Kind.success.systemImage, "checkmark.circle.fill")
        XCTAssertEqual(InfoMessage.Kind.warning.systemImage, "exclamationmark.triangle.fill")
        XCTAssertEqual(InfoMessage.Kind.error.systemImage, "exclamationmark.circle.fill")
    }

    func testCustomIconOverridesKindDefault() {
        let custom = InfoMessage("x", kind: .error, systemImage: "bolt.fill")
        XCTAssertEqual(custom.resolvedSystemImage, "bolt.fill")
        let plain = InfoMessage("y", kind: .error)
        XCTAssertEqual(plain.resolvedSystemImage, "exclamationmark.circle.fill")
        let info = InfoMessage("z", kind: .info)
        XCTAssertNil(info.resolvedSystemImage)
    }

    func testEqualityIgnoresIdentity() {
        XCTAssertEqual(InfoMessage("same", kind: .warning), InfoMessage("same", kind: .warning))
        XCTAssertNotEqual(InfoMessage("a", kind: .warning), InfoMessage("a", kind: .error))
    }
}
