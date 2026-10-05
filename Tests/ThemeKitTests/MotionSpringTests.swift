//
//  MotionSpringTests.swift
//  ThemeKitTests
//
//  The motion tokens shared with Compose / Material 3: the springs' numbers and response, the
//  gate, the curves, the shake's beats and the opt-in selection tick.
//

import XCTest
import SwiftUI
@testable import ThemeKit

final class MotionSpringTests: XCTestCase {
    /// Compose's and Material 3's numbers, by name.
    func testTheSpringsAreComposesNumbers() {
        let expected: [MotionSpring: (stiffness: Double, ratio: Double)] = [
            .value: (1500, 1), .layout: (400, 1), .sheet: (700, 0.9), .effect: (1600, 1),
            .exit: (3800, 1), .nudge: (6000, 1), .settle: (1500, 0.5),
        ]
        for spring in MotionSpring.allCases {
            XCTAssertEqual(spring.stiffness, expected[spring]?.stiffness, spring.rawValue)
            XCTAssertEqual(spring.dampingRatio, expected[spring]?.ratio, spring.rawValue)
        }
    }

    /// `response = 2π / √stiffness`: 0.314s for `layout`, 0.162s for `value`.
    func testTheResponseIsTheUndampedPeriod() {
        XCTAssertEqual(MotionSpring.layout.response, 0.314, accuracy: 0.001)
        XCTAssertEqual(MotionSpring.value.response, 0.162, accuracy: 0.001)
        XCTAssertEqual(MotionSpring.sheet.response, 0.237, accuracy: 0.001)
        XCTAssertEqual(MotionSpring.nudge.response, 0.081, accuracy: 0.001)
    }

    /// The gate: no animation with the switch off or Reduce Motion on.
    func testTheSpringIsGated() {
        XCTAssertNotNil(MicroMotion.animation(MotionSpring.layout, enabled: true, reduceMotion: false))
        XCTAssertNil(MicroMotion.animation(MotionSpring.layout, enabled: false, reduceMotion: false))
        XCTAssertNil(MicroMotion.animation(MotionSpring.layout, enabled: true, reduceMotion: true))
    }

    /// The curves exist for every duration (and stay distinct from the symmetric default).
    func testTheCurvesFollowTheDuration() {
        for token in Motion.allCases {
            XCTAssertNotEqual(token.standard, token.animation, token.rawValue)
            XCTAssertNotEqual(token.decelerate, token.accelerate, token.rawValue)
            XCTAssertEqual(token.standard, .timingCurve(0.4, 0, 0.2, 1, duration: token.duration), token.rawValue)
        }
    }

    /// Four beats, alternating, each 60% of the last.
    func testTheShakesBeats() {
        let beats = ShakeBeats.offsets(amplitude: 16)
        XCTAssertEqual(beats.count, 4)
        for (beat, expected) in zip(beats, [16, -9.6, 5.76, -3.456] as [CGFloat]) {
            XCTAssertEqual(beat, expected, accuracy: 0.0001)
        }
        XCTAssertTrue(ShakeBeats.offsets(amplitude: 16, beats: 0).isEmpty)
    }

    /// The selection tick is off unless a subtree asks for it.
    func testSelectionHapticsAreOptIn() {
        XCTAssertFalse(EnvironmentValues().selectionHaptics)
        var values = EnvironmentValues()
        values.selectionHaptics = true
        XCTAssertTrue(values.selectionHaptics)
    }
}
