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
