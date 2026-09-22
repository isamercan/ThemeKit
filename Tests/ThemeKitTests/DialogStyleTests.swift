//
//  DialogStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 22.09.2026.
//
//  `DialogCard` + `DialogStyle`: the built-in card still draws the 1.8.1 pixels
//  (the `lg` margin moved into the card and moved nothing), the stock style
//  draws the same pixels through `makeBody`, a custom style receives the card's
//  content and actions from both `.dialog(isPresented:title:…)` and
//  `FeedbackPresenter.confirm(…)`, the actions keep ThemeKit's loading and
//  dismissal, and ThemeKit adds no margin around a custom card.
//
//  Every render here runs with Reduce Transparency on. The stock card's chrome
//  is `glassChrome` — Liquid Glass on OS 26, which neither `ImageRenderer` nor
//  an offscreen layer render draws — so the pixels both paths are compared on
//  are its opaque fallback, which renders everywhere. Both paths apply the same
//  `glassChrome(in:)` call; the snapshot suite pins the glass itself.
//

import XCTest
import SwiftUI
@testable import ThemeKit

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class DialogStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        for fixture in dialogCases {
            XCTAssertNotNil(render(presented(fixture)), fixture.label)
            XCTAssertTrue(drawsInk(presented(fixture)), "\(fixture.label): the fixture renders blank")
        }
    }

    /// With no style set, the card draws the 1.8.1 pixels: the `lg` margin the
    /// callers applied around it now sits inside it, which must move nothing.
    func testBuiltInCardDrawsThe181Pixels() {
        for fixture in dialogCases {
            let delta = pixelDelta(presented(fixture), recipe(fixture))
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(fixture.label): the built-in card drifted from 1.8.1")
            // Control, same case: the recipe at 60% opacity must be caught.
            XCTAssertTrue(differs(presented(fixture), recipe(fixture, opacity: 0.6)),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    /// The loading state the stock card draws (spinning primary, disabled
    /// secondary) is the 1.8.1 one too.
    func testBuiltInLoadingCardDrawsThe181Pixels() {
        let card = DialogCard(title: "Pay now?", message: "We'll charge your card.",
                              primaryTitle: "Pay", onPrimary: {},
                              secondaryTitle: "Cancel", onSecondary: {},
                              isPrimaryLoading: true)
        let old = V181DialogCard(title: "Pay now?", message: "We'll charge your card.", primaryTitle: "Pay",
                                 secondaryTitle: "Cancel", isPrimaryLoading: true)
            .padding(Theme.SpacingKey.lg.value)
        XCTAssertTrue(drawsInk(staged(card)), "the fixture renders blank")
        let delta = pixelDelta(staged(card), staged(old))
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "the loading card drifted from 1.8.1")
    }

    /// `.dialogStyle(.default)` goes through `makeBody`, yet must draw the same
    /// pixels as the untouched built-in path.
    func testDefaultStyleDrawsTheBuiltInPixels() {
        for fixture in dialogCases {
            let styled = presented(fixture).dialogStyle(.default)
            let delta = pixelDelta(presented(fixture), styled)
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(fixture.label): .default drifted from the built-in card")
            XCTAssertTrue(drawsInk(styled), "\(fixture.label): the .default fixture renders blank")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            XCTAssertTrue(differs(presented(fixture), presented(fixture).dialogStyle(DimmedDefaultDialogStyle())),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    /// The same parity for the loading state, and for a card the default
    /// corner-radius role doesn't draw.
    func testDefaultStyleDrawsTheBuiltInLoadingAndCornerPixels() {
        let loading = DialogCard(title: "Pay now?", message: "We'll charge your card.",
                                 primaryTitle: "Pay", onPrimary: {},
                                 secondaryTitle: "Cancel", onSecondary: {},
                                 primaryColor: .success, isPrimaryLoading: true)
        XCTAssertLessThanOrEqual(pixelDelta(staged(loading), staged(loading.dialogStyle(.default))) ?? .max, pixelNoise,
                                 ".default drifted on the loading card")

        let fixture = dialogCases[1]
        let tight = presented(fixture).dialogCornerRadius(.selector)
        XCTAssertLessThanOrEqual(pixelDelta(tight, tight.dialogStyle(.default)) ?? .max, pixelNoise,
                                 ".default ignored .dialogCornerRadius(_:)")
        XCTAssertTrue(differs(tight, presented(fixture)), "control: the corner role is a visible difference")
    }

    /// `FeedbackPresenter.confirm(…)` draws the same card: `.default` matches
    /// the built-in confirm card too.
    func testDefaultStyleDrawsTheBuiltInConfirmPixels() async throws {
        let request = { (feedback: FeedbackPresenter) in
            feedback.confirm(title: "Delete trip?", message: "This action cannot be undone.",
                             primaryTitle: "Delete", primaryKind: .error)
        }
        let builtIn = try await confirmRender(seed: request)
        let styled = try await confirmRender(seed: request) { $0.dialogStyle(.default) }
        let dimmed = try await confirmRender(seed: request) { $0.dialogStyle(DimmedDefaultDialogStyle()) }
        let empty = try await confirmRender(seed: { _ in })
        XCTAssertLessThanOrEqual(maxDelta(builtIn, styled) ?? .max, pixelNoise, ".default drifted from the confirm card")
        XCTAssertGreaterThan(maxDelta(builtIn, dimmed) ?? .max, pixelNoise, "control: the comparison saw no difference")
        XCTAssertGreaterThan(maxDelta(builtIn, empty) ?? .max, pixelNoise, "control: the confirm card drew nothing")
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().dialogStyle.isDefault)
        XCTAssertFalse(AnyDialogStyle(DefaultDialogStyle()).isDefault)
    }

    /// With no style set up the tree, the card never asks any style to draw:
    /// a style set on a sibling isn't consulted, and the card still draws the
    /// built-in pixels.
    func testDefaultPathDrawsNoCustomStyle() {
        let recorder = DialogConfigurationRecorder()
        let fixture = dialogCases[1]
        let pair = VStack(spacing: 0) {
            presented(fixture)
            Color.clear.frame(width: 360, height: 40).dialogStyle(RecordingDialogStyle(recorder: recorder))
        }
        _ = render(pair)
        XCTAssertTrue(recorder.values.isEmpty, "a style off the dialog's path was consulted")
        XCTAssertLessThanOrEqual(pixelDelta(presented(fixture), recipe(fixture)) ?? .max, pixelNoise)
    }

    // MARK: Custom style — `.dialog(isPresented:title:…)`

    func testCustomStyleReceivesTheDialogsContent() throws {
        let recorder = DialogConfigurationRecorder()
        _ = render(Color.clear.frame(width: 360, height: 480)
            .dialog(isPresented: .constant(true), title: "Payment failed",
                    message: "Your card was declined.",
                    primaryTitle: "Retry", secondaryTitle: "Cancel", onSecondary: {},
                    kind: .error, closable: true)
            .dialogStyle(RecordingDialogStyle(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.title, "Payment failed")
        XCTAssertEqual(c.message, "Your card was declined.")
        XCTAssertEqual(c.kind, .error)
        XCTAssertEqual(c.primaryAction.title, "Retry")
        XCTAssertEqual(c.primaryAction.color, .error, "the primary takes the kind's colour")
        XCTAssertFalse(c.primaryAction.isLoading)
        XCTAssertFalse(c.primaryAction.isDisabled)
        let secondary = try XCTUnwrap(c.secondaryAction)
        XCTAssertEqual(secondary.title, "Cancel")
        XCTAssertNil(secondary.color, "the secondary never takes a colour")
        XCTAssertFalse(secondary.isLoading)
        XCTAssertFalse(secondary.isDisabled)
        XCTAssertNotNil(c.onClose, "closable → a close handler")
        XCTAssertEqual(c.maxWidth, 320)
        XCTAssertEqual(c.stockMargin, Theme.SpacingKey.lg.value)
    }

    func testDefaultsReachTheStyle() throws {
        let recorder = DialogConfigurationRecorder()
        _ = render(Color.clear.frame(width: 360, height: 480)
            .dialog(isPresented: .constant(true), title: "Saved", primaryTitle: "OK")
            .dialogStyle(RecordingDialogStyle(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.title, "Saved")
        XCTAssertNil(c.message)
        XCTAssertNil(c.kind)
        XCTAssertEqual(c.primaryAction.title, "OK")
        XCTAssertNil(c.primaryAction.color, "no kind → the stock primary")
        XCTAssertNil(c.secondaryAction)
        XCTAssertNil(c.onClose, "not closable → no close handler")
        XCTAssertEqual(c.maxWidth, 320)
        XCTAssertEqual(c.stockMargin, Theme.SpacingKey.lg.value)
    }

    /// A secondary needs both halves: a title with no handler draws none on
    /// the stock card, so it reaches no style either.
    func testSecondaryNeedsATitleAndAHandler() throws {
        let recorder = DialogConfigurationRecorder()
        _ = render(Color.clear.frame(width: 360, height: 480)
            .dialog(isPresented: .constant(true), title: "Saved", primaryTitle: "OK", secondaryTitle: "Cancel")
            .dialogStyle(RecordingDialogStyle(recorder: recorder)))
        XCTAssertNil(try XCTUnwrap(recorder.values.last).secondaryAction)
    }

    /// `maxWidth` is the width the caller asked for: `width:`, then `size:`,
    /// then 320.
    func testMaxWidthFollowsWidthThenSizeThenTheDefault() throws {
        func maxWidth(size: DialogSize?, width: CGFloat?) throws -> CGFloat {
            let recorder = DialogConfigurationRecorder()
            _ = render(Color.clear.frame(width: 360, height: 480)
                .dialog(isPresented: .constant(true), title: "Saved", primaryTitle: "OK", size: size, width: width)
                .dialogStyle(RecordingDialogStyle(recorder: recorder)))
            return try XCTUnwrap(recorder.values.last).maxWidth
        }
        XCTAssertEqual(try maxWidth(size: nil, width: nil), 320)
        XCTAssertEqual(try maxWidth(size: .lg, width: nil), 480)
        XCTAssertEqual(try maxWidth(size: .xl, width: nil), 560)
        XCTAssertEqual(try maxWidth(size: .lg, width: 280), 280, "an explicit width wins over the size")
        XCTAssertEqual(try maxWidth(size: .full, width: nil), .infinity)
    }

    /// Each action does what the stock button does: the secondary and the
    /// close button dismiss (the secondary then runs the caller's handler), and
    /// the primary runs the caller's work and then dismisses.
    func testActionsRunTheCallersHandlersAndDismiss() async throws {
        // Secondary.
        do {
            let state = PresentationBox()
            let recorder = DialogConfigurationRecorder()
            var secondaryRan = 0
            _ = render(dialog(state, recorder: recorder, onSecondary: { secondaryRan += 1 }))
            try XCTUnwrap(recorder.values.last?.secondaryAction).perform()
            XCTAssertEqual(secondaryRan, 1, "the caller's secondary handler ran")
            XCTAssertFalse(state.isPresented, "the secondary dismissed")
        }
        // Close.
        do {
            let state = PresentationBox()
            let recorder = DialogConfigurationRecorder()
            _ = render(dialog(state, recorder: recorder, closable: true))
            try XCTUnwrap(recorder.values.last?.onClose)()
            XCTAssertFalse(state.isPresented, "the close button dismissed")
        }
        // Primary (its work runs in ThemeKit's task, so host it live).
        do {
            let state = PresentationBox()
            let recorder = DialogConfigurationRecorder()
            let work = WorkCounter()
            let host = LiveHost(dialog(state, recorder: recorder, onPrimary: { work.count += 1 }))
            try XCTUnwrap(recorder.values.last).primaryAction.perform()
            await host.settle { !state.isPresented }
            XCTAssertEqual(work.count, 1, "the caller's primary ran")
            XCTAssertFalse(state.isPresented, "the primary dismissed once its work ended")
            host.tearDown()
        }
    }

    /// While an async primary runs, the style is told to spin the primary and
    /// disable the secondary, the close button goes away, and the actions do
    /// nothing; when the work ends the dialog dismisses.
    func testAsyncPrimaryLoadsThenDismisses() async throws {
        let state = PresentationBox()
        let recorder = DialogConfigurationRecorder()
        let gate = WorkGate()
        let work = WorkCounter()
        var secondaryRan = 0
        let view = dialog(state, recorder: recorder, closable: true,
                          onPrimary: { work.count += 1; await gate.wait() },
                          onSecondary: { secondaryRan += 1 })
        let host = LiveHost(view)

        let idle = try XCTUnwrap(recorder.values.last)
        XCTAssertFalse(idle.primaryAction.isLoading)
        XCTAssertNotNil(idle.onClose)
        idle.primaryAction.perform()
        await settle { work.count == 1 }
        await host.settle { recorder.values.last?.primaryAction.isLoading == true }

        let loading = try XCTUnwrap(recorder.values.last)
        XCTAssertTrue(loading.primaryAction.isLoading, "the primary spins while the work runs")
        XCTAssertFalse(loading.primaryAction.isDisabled)
        XCTAssertEqual(loading.secondaryAction?.isDisabled, true, "the secondary is disabled meanwhile")
        XCTAssertEqual(loading.secondaryAction?.isLoading, false)
        XCTAssertNil(loading.onClose, "the close button goes away while the work runs, as on the stock card")
        XCTAssertTrue(state.isPresented, "the dialog stays up until the work ends")

        // A style whose button has no loading guard can't start the work twice
        // or run the secondary mid-flight.
        loading.primaryAction.perform()
        loading.secondaryAction?.perform()
        await host.settle { false }
        XCTAssertEqual(work.count, 1, "the primary ran again while loading")
        XCTAssertEqual(secondaryRan, 0, "the disabled secondary ran")
        XCTAssertTrue(state.isPresented)

        gate.open()
        await settle { !state.isPresented }
        XCTAssertFalse(state.isPresented, "the dialog dismissed once the work ended")
        host.tearDown()
    }

    // MARK: Custom style — `FeedbackPresenter.confirm(…)`

    func testConfirmReachesTheStyle() async throws {
        let recorder = DialogConfigurationRecorder()
        let probe = try await confirmHost(recorder: recorder) { feedback in
            feedback.confirm(title: "Delete trip?", message: "This action cannot be undone.",
                             primaryTitle: "Delete", primaryKind: .error)
        }
        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.title, "Delete trip?")
        XCTAssertEqual(c.message, "This action cannot be undone.")
        XCTAssertNil(c.kind, "confirm shows no kind icon")
        XCTAssertEqual(c.primaryAction.title, "Delete")
        XCTAssertEqual(c.primaryAction.color, .error, "the primary takes primaryKind's colour")
        XCTAssertFalse(c.primaryAction.isLoading, "confirm's primary is synchronous")
        XCTAssertEqual(c.secondaryAction?.title, String(themeKit: "Cancel"), "the default secondary")
        XCTAssertNil(c.secondaryAction?.color)
        XCTAssertEqual(c.secondaryAction?.isDisabled, false)
        XCTAssertNil(c.onClose, "confirm has no close button")
        XCTAssertEqual(c.maxWidth, 320)
        XCTAssertEqual(c.stockMargin, Theme.SpacingKey.lg.value)
        probe.tearDown()
    }

    func testConfirmDefaultsReachTheStyle() async throws {
        let recorder = DialogConfigurationRecorder()
        let probe = try await confirmHost(recorder: recorder) { feedback in
            feedback.confirm(title: "Sign out?", primaryTitle: "Sign out", secondaryTitle: nil)
        }
        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertNil(c.message)
        XCTAssertEqual(c.primaryAction.color, FeedbackKind.info.semanticColor,
                       "primaryKind defaults to .info, so confirm always sets a colour")
        XCTAssertNil(c.secondaryAction, "secondaryTitle: nil → no secondary")
        probe.tearDown()
    }

    func testConfirmActionsRunTheCallersHandlersAndDismiss() async throws {
        let primaryRan = WorkCounter()
        let secondaryRan = WorkCounter()
        let seed = { (feedback: FeedbackPresenter) in
            feedback.confirm(title: "Delete trip?", primaryTitle: "Delete",
                             onPrimary: { primaryRan.count += 1 },
                             onSecondary: { secondaryRan.count += 1 })
        }

        let primaryRecorder = DialogConfigurationRecorder()
        let first = try await confirmHost(recorder: primaryRecorder, seed: seed)
        try XCTUnwrap(primaryRecorder.values.last).primaryAction.perform()
        XCTAssertEqual(primaryRan.count, 1)
        XCTAssertNil(first.presenter?.activeConfirm, "the primary dismissed the confirm")
        first.tearDown()

        let secondaryRecorder = DialogConfigurationRecorder()
        let second = try await confirmHost(recorder: secondaryRecorder, seed: seed)
        try XCTUnwrap(secondaryRecorder.values.last?.secondaryAction).perform()
        XCTAssertEqual(secondaryRan.count, 1)
        XCTAssertEqual(primaryRan.count, 1, "the secondary didn't run the primary")
        XCTAssertNil(second.presenter?.activeConfirm, "the secondary dismissed the confirm")
        second.tearDown()
    }

    // MARK: Scope

    /// The style reaches the dialog it's set around and nothing else: not a
    /// sibling dialog, and not the slotted dialogs or `AlertDialog`.
    func testStyleReachesOnlyTheFixedLayoutCardItIsSetAround() {
        let recorder = DialogConfigurationRecorder()
        let style = RecordingDialogStyle(recorder: recorder)
        _ = render(VStack(spacing: 0) {
            Color.clear.frame(width: 360, height: 300)
                .dialog(isPresented: .constant(true), title: "Styled", primaryTitle: "OK")
                .dialogStyle(style)
            Color.clear.frame(width: 360, height: 300)
                .dialog(isPresented: .constant(true), title: "Sibling", primaryTitle: "OK")
        })
        XCTAssertEqual(recorder.values.map(\.title).filter { $0 != "Styled" }, [],
                       "the style reached a dialog it wasn't set around")
        XCTAssertTrue(recorder.values.contains { $0.title == "Styled" })

        let others = DialogConfigurationRecorder()
        _ = render(VStack(spacing: 0) {
            Color.clear.frame(width: 360, height: 300)
                .dialog(isPresented: .constant(true), title: "Slotted") { Text("Body") } footer: { Text("Footer") }
            Color.clear.frame(width: 360, height: 300)
                .dialog(isPresented: .constant(true)) { Text("Header") } content: { Text("Body") } footer: { Text("Footer") }
            Color.clear.frame(width: 360, height: 300)
                .dialog(isPresented: .constant(true)) { Text("Free-form") }
            AlertDialog("Alert", message: "Body").primaryAction("OK") {}
        }
        .dialogStyle(RecordingDialogStyle(recorder: others)))
        XCTAssertTrue(others.values.isEmpty, "the slotted dialogs and AlertDialog don't consult DialogStyle")
    }

    /// A style set at a container reaches every fixed-layout dialog below it.
    func testContainerStyleReachesNestedDialogs() {
        let recorder = DialogConfigurationRecorder()
        _ = render(VStack(spacing: 0) {
            Color.clear.frame(width: 360, height: 300)
                .dialog(isPresented: .constant(true), title: "First", primaryTitle: "OK")
            Color.clear.frame(width: 360, height: 300)
                .dialog(isPresented: .constant(true), title: "Second", primaryTitle: "OK")
        }
        .dialogStyle(RecordingDialogStyle(recorder: recorder)))
        XCTAssertTrue(recorder.values.contains { $0.title == "First" })
        XCTAssertTrue(recorder.values.contains { $0.title == "Second" })
    }

    // MARK: Margin

    /// ThemeKit adds no margin around a custom card: a `.full` card that fills
    /// its max width spans the whole presentation, edge to edge.
    func testCustomCardGetsNoThemeKitMargin() {
        let styled = Color.clear.frame(width: 360, height: 300)
            .dialog(isPresented: .constant(true), title: "Edge", primaryTitle: "OK", size: .full)
            .dialogStyle(SlabDialogStyle(margin: 0))
        let bare = slabRecipe(margin: 0)
        XCTAssertTrue(drawsInk(styled), "the fixture renders blank")
        let delta = pixelDelta(styled, bare)
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "ThemeKit put a margin around the custom card")
        // Control: the stock margin is a visible difference.
        XCTAssertTrue(differs(styled, slabRecipe(margin: Theme.SpacingKey.lg.value)), "control: the comparison saw no difference")
    }

    /// A style that wants the stock clearance pads by `stockMargin` and lands
    /// exactly where the stock card's margin would put it.
    func testStockMarginMatchesTheStockCardsClearance() {
        let styled = Color.clear.frame(width: 360, height: 300)
            .dialog(isPresented: .constant(true), title: "Edge", primaryTitle: "OK", size: .full)
            .dialogStyle(SlabDialogStyle(margin: nil))
        let delta = pixelDelta(styled, slabRecipe(margin: Theme.SpacingKey.lg.value))
        XCTAssertNotNil(delta, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "stockMargin isn't the stock card's margin")
    }

    // MARK: Fixtures

    private var dialogCases: [DialogCase] {
        [
            DialogCase(label: "title only", title: "Saved", primaryTitle: "OK"),
            DialogCase(label: "message + secondary", message: "This action cannot be undone.",
                       secondaryTitle: "Cancel"),
            DialogCase(label: "kind + closable", title: "Payment failed",
                       message: "Your card was declined. Try another method.",
                       primaryTitle: "Retry", secondaryTitle: "Cancel", kind: .error, closable: true),
            DialogCase(label: "success kind, no message", title: "Booked", primaryTitle: "Done", kind: .success),
            DialogCase(label: "narrow width", message: "This action cannot be undone.", width: 240),
            DialogCase(label: "full size, bottom", message: "You'll need to log in again next time.",
                       primaryTitle: "Sign out", secondaryTitle: "Cancel", size: .full, placement: .bottom),
        ]
    }

    /// The fixture presented through the real `.dialog(isPresented:title:…)`.
    private func presented(_ fixture: DialogCase) -> some View {
        Color.clear.frame(width: 360, height: 480)
            .dialog(isPresented: .constant(true), title: fixture.title, message: fixture.message,
                    primaryTitle: fixture.primaryTitle,
                    secondaryTitle: fixture.secondaryTitle, onSecondary: fixture.secondaryTitle.map { _ in {} },
                    kind: fixture.kind, closable: fixture.closable,
                    size: fixture.size, placement: fixture.placement, width: fixture.width)
    }

    /// The same fixture as 1.8.1 drew it: the old card body with the callers'
    /// `lg` margin around it, in the shared presentation.
    private func recipe(_ fixture: DialogCase, opacity: Double = 1) -> some View {
        Color.clear.frame(width: 360, height: 480).overlay {
            DialogPresentation(swipeToDismiss: false, backdrop: .dim, placement: fixture.placement,
                               onScrimTap: {}, onSwipeDismiss: {}, card: {
                V181DialogCard(title: fixture.title, message: fixture.message,
                               primaryTitle: fixture.primaryTitle, secondaryTitle: fixture.secondaryTitle,
                               primaryColor: fixture.kind?.semanticColor, kind: fixture.kind,
                               closable: fixture.closable,
                               width: fixture.width ?? fixture.size?.width ?? 320)
                    .padding(Theme.SpacingKey.lg.value)
                    .opacity(opacity)
            })
        }
    }

    /// A plain slab in the shared presentation — what `SlabDialogStyle` draws,
    /// with the given margin (or none) around it.
    private func slabRecipe(margin: CGFloat) -> some View {
        Color.clear.frame(width: 360, height: 300).overlay {
            DialogPresentation(swipeToDismiss: false, backdrop: .dim, placement: .center,
                               onScrimTap: {}, onSwipeDismiss: {}, card: {
                SlabDialogStyle.slab.padding(margin)
            })
        }
    }

    private func dialog(_ state: PresentationBox, recorder: DialogConfigurationRecorder,
                        closable: Bool = false,
                        onPrimary: @escaping () async -> Void = {},
                        onSecondary: @escaping () -> Void = {}) -> some View {
        Color.clear.frame(width: 360, height: 480)
            .dialog(isPresented: state.binding, title: "Pay now?", message: "We'll charge your card.",
                    primaryTitle: "Pay", onPrimary: onPrimary,
                    secondaryTitle: "Cancel", onSecondary: onSecondary,
                    closable: closable)
            .dialogStyle(RecordingDialogStyle(recorder: recorder))
    }

    /// Hosts a `.feedbackHost()` live, seeds a confirm on its presenter, and
    /// waits until the confirm card has been drawn through `recorder`'s style.
    private func confirmHost(recorder: DialogConfigurationRecorder,
                             seed: @escaping (FeedbackPresenter) -> Void) async throws -> ConfirmProbe {
        let probe = ConfirmProbe()
        let host = LiveHost(PresenterReader(probe: probe)
            .feedbackHost()
            .dialogStyle(RecordingDialogStyle(recorder: recorder)))
        probe.host = host
        await host.settle { probe.presenter != nil }
        seed(try XCTUnwrap(probe.presenter, "the host never handed out its presenter"))
        await host.settle { !recorder.values.isEmpty }
        XCTAssertFalse(recorder.values.isEmpty, "the confirm card never reached the style")
        return probe
    }

    /// Renders a live `.feedbackHost()` with a seeded confirm and returns its
    /// bitmap.
    private func confirmRender(seed: @escaping (FeedbackPresenter) -> Void) async throws -> Bitmap? {
        try await confirmRender(seed: seed) { $0 }
    }

    /// The same, wrapped (to set a style around the host).
    private func confirmRender<Wrapped: View>(seed: @escaping (FeedbackPresenter) -> Void,
                                              wrap: (AnyView) -> Wrapped) async throws -> Bitmap? {
        let probe = ConfirmProbe()
        let host = LiveHost(wrap(AnyView(PresenterReader(probe: probe).feedbackHost()))
            .environment(\._accessibilityReduceTransparency, true))
        await host.settle { probe.presenter != nil }
        seed(try XCTUnwrap(probe.presenter, "the host never handed out its presenter"))
        await host.settle { false }
        defer { host.tearDown() }
        return host.bitmap()
    }

    private func staged(_ view: some View) -> some View {
        view.frame(width: 360).padding(8)
    }

    private func render(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view.environment(\._accessibilityReduceTransparency, true))
        renderer.scale = 2
        return renderer.cgImage
    }

    private func drawsInk(_ view: some View) -> Bool {
        _ = render(view)
        guard let image = render(view), let data = image.dataProvider?.data as Data?, let first = data.first
        else { return false }
        return data.contains { $0 != first }
    }

    /// The largest per-channel difference between two renders, or `nil` when
    /// either fails to render or their sizes differ. Each view renders twice
    /// and keeps the second; callers treat a delta up to `pixelNoise` as
    /// identical.
    private func pixelDelta<A: View, B: View>(_ a: A, _ b: B) -> Int? {
        _ = render(a)
        _ = render(b)
        guard let x = render(a), let y = render(b), x.width == y.width, x.height == y.height,
              let dx = x.dataProvider?.data as Data?, let dy = y.dataProvider?.data as Data?,
              dx.count == dy.count else { return nil }
        return zip(dx, dy).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }

    private func maxDelta(_ a: Bitmap?, _ b: Bitmap?) -> Int? {
        guard let a, let b, a.width == b.width, a.height == b.height, a.bytes.count == b.bytes.count else { return nil }
        return zip(a.bytes, b.bytes).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }

    /// `true` when two renders are visibly different — either their sizes
    /// differ or a channel moved past the antialiasing noise floor.
    private func differs<A: View, B: View>(_ a: A, _ b: B) -> Bool {
        guard let delta = pixelDelta(a, b) else { return true }
        return delta > pixelNoise
    }

    /// Polls `condition` on the main actor, letting tasks run, for up to two
    /// seconds.
    private func settle(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private let pixelNoise = 2
}

// MARK: - The 1.8.1 recipe (the card written out)

/// `DialogCard`'s 1.8.1 body, written out: the reference the built-in path must
/// still draw (with the callers' `lg` margin applied around it by the recipe).
/// The icons take their tint through `colorOverride(_:)`, the non-deprecated
/// spelling of the same raw tint the 1.8.1 body's `color(_:)` applied.
@available(iOS 16.0, macOS 13.0, *)
private struct V181DialogCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.dialogCornerRadius) private var cornerRadiusRole

    let title: String
    var message: String?
    let primaryTitle: String
    var secondaryTitle: String?
    var primaryColor: SemanticColor?
    var kind: FeedbackKind?
    var closable = false
    var width: CGFloat?
    var isPrimaryLoading = false

    /// The recipe's buttons do nothing; the pixels are what matter.
    private func noop() {}

    var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            if let kind {
                Icon(systemName: kind.systemImage).size(.xl).colorOverride(theme.resolve(kind.semanticColor).accent)
            }
            VStack(spacing: Theme.SpacingKey.sm.value) {
                Text(title)
                    .textStyle(.headingSm)
                    .foregroundStyle(theme.text(.textPrimary))
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: Theme.SpacingKey.sm.value) {
                if let primaryColor {
                    ThemeButton(primaryTitle, action: noop)
                        .color(primaryColor).fullWidth().loading(isPrimaryLoading)
                } else {
                    PrimaryButton(primaryTitle, action: noop).loading(isPrimaryLoading)
                }
                if let secondaryTitle {
                    OutlineButton(secondaryTitle, action: noop).disabled(isPrimaryLoading)
                }
            }
        }
        .padding(Theme.SpacingKey.lg.value)
        .frame(maxWidth: width ?? 320)
        .glassChrome(in: RoundedRectangle(cornerRadius: theme.radius(cornerRadiusRole), style: .continuous))
        .overlay(alignment: .topTrailing) {
            if closable {
                Button(action: noop) {
                    Icon(systemName: "xmark").size(.sm).colorOverride(theme.text(.textTertiary))
                        .padding(Theme.SpacingKey.md.value)
                }
                .buttonStyle(.plain)
            }
        }
        .themeShadow(.elevated)
    }
}

// MARK: - Fixtures

private struct DialogCase {
    let label: String
    var title = "Delete trip?"
    var message: String?
    var primaryTitle = "Delete"
    var secondaryTitle: String?
    var kind: FeedbackKind?
    var closable = false
    var size: DialogSize?
    var width: CGFloat?
    var placement: DialogPlacement = .center
}

@MainActor
private final class DialogConfigurationRecorder {
    var values: [DialogStyleConfiguration] = []
}

private struct RecordingDialogStyle: DialogStyle {
    let recorder: DialogConfigurationRecorder

    @MainActor
    func makeBody(configuration: DialogStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return VStack {
            Text(configuration.title)
            Text(configuration.primaryAction.title)
        }
    }
}

/// The stock card at 60% opacity — the control for the pixel-parity loops.
private struct DimmedDefaultDialogStyle: DialogStyle {
    func makeBody(configuration: DialogStyleConfiguration) -> some View {
        DefaultDialogStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}

/// A flat slab filling the card's max width, padded by the given margin — or
/// by `stockMargin` when `margin` is `nil`. The margin proof.
private struct SlabDialogStyle: DialogStyle {
    let margin: CGFloat?

    @MainActor static var slab: some View {
        Rectangle().fill(Color.red).frame(maxWidth: .infinity).frame(height: 80)
    }

    func makeBody(configuration: DialogStyleConfiguration) -> some View {
        Rectangle().fill(Color.red).frame(maxWidth: configuration.maxWidth).frame(height: 80)
            .padding(margin ?? configuration.stockMargin)
    }
}

/// A `Binding<Bool>` whose value a test can read after the dialog writes it.
@MainActor
private final class PresentationBox {
    var isPresented = true
    var binding: Binding<Bool> {
        Binding(get: { self.isPresented }, set: { self.isPresented = $0 })
    }
}

@MainActor
private final class WorkCounter {
    var count = 0
}

/// Async work a test finishes by hand.
@MainActor
private final class WorkGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

/// Holds the presenter a `.feedbackHost()` hands its content, and the live
/// host keeping it alive.
@MainActor
private final class ConfirmProbe {
    var presenter: FeedbackPresenter?
    var host: LiveHost?
    func tearDown() { host?.tearDown() }
}

private struct PresenterReader: View {
    let probe: ConfirmProbe
    @EnvironmentObject private var feedback: FeedbackPresenter

    var body: some View {
        Color.clear
            .frame(width: 360, height: 480)
            .onAppear { probe.presenter = feedback }
    }
}

private struct Bitmap {
    let width: Int
    let height: Int
    let bytes: [UInt8]
}

// MARK: - Live host

/// A real hosting view in a window, so `@State` / `@StateObject` updates and
/// `Task`s re-render the tree the way they do in an app (an `ImageRenderer`
/// render doesn't run the update loop).
@MainActor
private final class LiveHost {
    #if canImport(UIKit)
    private let controller: UIHostingController<AnyView>
    private let window: UIWindow
    #else
    private let view: NSHostingView<AnyView>
    private let window: NSWindow
    #endif

    init(_ root: some View) {
        let size = CGSize(width: 360, height: 480)
        #if canImport(UIKit)
        controller = UIHostingController(rootView: AnyView(root))
        window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #else
        view = NSHostingView(rootView: AnyView(root))
        view.frame = CGRect(origin: .zero, size: size)
        window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        #endif
        pump()
    }

    /// Runs the main loop (layout, updates, tasks) until `condition` holds, or
    /// for half a second when it never does.
    func settle(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(condition() ? 0 : 0.5)
        repeat {
            pump()
            try? await Task.sleep(nanoseconds: 10_000_000)
        } while !condition() && Date() < deadline
        pump()
    }

    /// The hosted view's current pixels, drawn at 2x.
    func bitmap() -> Bitmap? {
        #if canImport(UIKit)
        let bounds = controller.view.bounds
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        // The layer tree, not `drawHierarchy`: the test host's window has no
        // scene, so it is never on screen for a hierarchy snapshot.
        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            controller.view.layer.render(in: context.cgContext)
        }
        guard let cgImage = image.cgImage else { return nil }
        #else
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let cgImage = rep.cgImage else { return nil }
        #endif
        let w = cgImage.width, h = cgImage.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return drawn ? Bitmap(width: w, height: h, bytes: bytes) : nil
    }

    func tearDown() {
        #if canImport(UIKit)
        window.isHidden = true
        #else
        window.orderOut(nil)
        window.contentView = nil
        #endif
    }

    private func pump() {
        #if canImport(UIKit)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #else
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        #endif
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }
}
