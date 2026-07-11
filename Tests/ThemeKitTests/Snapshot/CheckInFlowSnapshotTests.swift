//
//  CheckInFlowSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the ThemeKitTravel `CheckInFlow` scaffold
//  (F3.4): first-step chrome (Back disabled), middle-step chrome (derived
//  done/active/todo header states), and last-step chrome (Done button), plus
//  an accented RTL pass. iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit
import ThemeKitTravel

@MainActor
final class CheckInFlowSnapshotTests: SnapshotTestCase {

    private var steps: [Steps.Step] {
        [
            .init("Passengers", state: .active),
            .init("Seats", state: .todo),
            .init("Boarding pass", state: .todo),
        ]
    }

    private func flow(at index: Int) -> some View {
        CheckInFlow(steps: steps, selection: .constant(index)) { page in
            Text("Page \(page + 1)")
                .textStyle(.bodyBase400)
                .padding()
        }
        .frame(height: 320)
    }

    // MARK: CheckInFlow (F3.4) — progression chrome

    /// First step: header shows active/todo/todo; Back is disabled.
    func testCheckInFlow_firstStep() {
        assertComponentSnapshot(flow(at: 0).padding())
    }

    /// Middle step: header derives done/active/todo from the selection.
    func testCheckInFlow_middleStep() {
        assertComponentSnapshot(flow(at: 1).padding())
    }

    /// Last step: the advancing button becomes Done.
    func testCheckInFlow_lastStep() {
        assertComponentSnapshot(flow(at: 2).padding())
    }

    /// Accented markers + mirrored chrome under RTL.
    func testCheckInFlow_middleStep_accent_rtl() {
        assertComponentSnapshot(
            CheckInFlow(steps: steps, selection: .constant(1)) { page in
                Text("Page \(page + 1)")
                    .textStyle(.bodyBase400)
                    .padding()
            }
            .accent(.success)
            .frame(height: 320)
            .padding(),
            layoutDirection: .rightToLeft
        )
    }
}
#endif
