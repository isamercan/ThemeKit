//
//  FeedbackPresenterTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Pure-logic coverage for the stacked toast model on FeedbackPresenter
//  (stacking, visible cap, dismissal, sticky toasts, and the async task morph).
//

import XCTest
@testable import ThemeKit

@MainActor
final class FeedbackPresenterTests: XCTestCase {

    func testToastsStackInOrder() {
        let p = FeedbackPresenter()
        p.toast("a")
        p.toast("b")
        XCTAssertEqual(p.toasts.map(\.title), ["a", "b"])
    }

    func testStackCapDropsOldest() {
        let p = FeedbackPresenter(maxVisibleToasts: 2)
        p.toast("a")
        p.toast("b")
        p.toast("c")
        XCTAssertEqual(p.toasts.map(\.title), ["b", "c"])
    }

    func testDismissByID() {
        let p = FeedbackPresenter()
        let id = p.toast("a")
        p.toast("b")
        p.dismissToast(id)
        XCTAssertEqual(p.toasts.map(\.title), ["b"])
    }

    func testDismissAllToasts() {
        let p = FeedbackPresenter()
        p.toast("a")
        p.toast("b")
        p.dismissAllToasts()
        XCTAssertTrue(p.toasts.isEmpty)
    }

    func testStickyToastWithActionHasNoDuration() {
        let p = FeedbackPresenter()
        p.toast("Deleted", kind: .info, action: ToastAction("Undo") {}, duration: nil)
        XCTAssertNil(p.toasts.first?.duration)
        XCTAssertNotNil(p.toasts.first?.action)
    }

    // MARK: FeedbackDefaults plumbing (unit 6)

    /// Omitting `duration:` marks the item so the host layer can substitute
    /// `FeedbackDefaults.toastDuration`; passing it (incl. `nil` = sticky) pins it.
    func testOmittedDurationIsMarkedForDefaults() {
        let p = FeedbackPresenter()
        p.toast("a")                    // omitted → follows the subtree default
        p.toast("b", duration: 3)       // explicit
        p.toast("c", duration: nil)     // explicit sticky
        XCTAssertEqual(p.toasts.map(\.hasExplicitDuration), [false, true, true])
        XCTAssertEqual(p.toasts[0].duration, 2.5)   // stock fallback carried on the item
    }

    func testNotifyOmittedDurationIsMarkedForDefaults() {
        let p = FeedbackPresenter()
        p.notify("t")
        XCTAssertEqual(p.activeNotification?.hasExplicitDuration, false)
        p.notify("t", duration: 6)
        XCTAssertEqual(p.activeNotification?.hasExplicitDuration, true)
    }

    /// The host syncs `FeedbackDefaults.maxVisibleToasts` onto the presenter's
    /// (now-internal-var) cap; it applies from the next enqueue.
    func testMaxVisibleToastsVarAppliesOnNextEnqueue() {
        let p = FeedbackPresenter(maxVisibleToasts: 3)
        p.toast("a"); p.toast("b"); p.toast("c")
        p.maxVisibleToasts = 1
        p.toast("d")
        XCTAssertEqual(p.toasts.map(\.title), ["d"])
    }

    func testToastTaskSuccessMorphsInPlace() async {
        let p = FeedbackPresenter()
        await p.toastTask(loading: "Saving…", success: "Saved") { /* immediate success */ }
        XCTAssertEqual(p.toasts.count, 1)
        XCTAssertEqual(p.toasts.first?.title, "Saved")
        XCTAssertEqual(p.toasts.first?.kind, .success)
        XCTAssertEqual(p.toasts.first?.isLoading, false)
    }

    func testToastTaskFailureMorphsToError() async {
        struct Boom: Error {}
        let p = FeedbackPresenter()
        await p.toastTask(loading: "Saving…", success: "Saved", failure: { _ in "Failed" }) {
            throw Boom()
        }
        XCTAssertEqual(p.toasts.first?.title, "Failed")
        XCTAssertEqual(p.toasts.first?.kind, .error)
    }
}
