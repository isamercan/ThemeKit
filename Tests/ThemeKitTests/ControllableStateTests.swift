//
//  ControllableStateTests.swift
//  ThemeKitTests
//
//  Parity coverage for the ControllableState property wrapper (ADR-4) and the
//  behavior-neutral Accordion/AccordionGroup refactor onto it: controlled writes
//  flow through the caller's binding, uncontrolled writes stay internal, both
//  modes reach the same state when toggled, and both Accordion inits render
//  pixel-identically for the same expansion state.
//

import SwiftUI
import XCTest
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)   // ImageRenderer-based pixel helper (matches the sibling render suites)
final class ControllableStateTests: XCTestCase {

    // MARK: Wrapper-level routing (no view graph needed — the controlled path
    // reads/writes only the captured binding)

    /// Controlled mode: a write through the wrapper must land in the caller's
    /// binding, and reads must reflect it.
    @MainActor
    func testControlledWritePropagatesToCallerBinding() {
        var box = false
        let state = ControllableState(wrappedValue: false, external: Binding(get: { box }, set: { box = $0 }))

        state.wrappedValue = true

        XCTAssertTrue(box, "A controlled write must propagate to the caller's binding.")
        XCTAssertTrue(state.wrappedValue, "Reads must reflect the caller's binding after a controlled write.")
    }

    /// The projected `Binding` (`$value`) must route to the caller's binding in
    /// controlled mode — it's what gets handed to child views and gestures.
    @MainActor
    func testProjectedBindingRoutesToCallerBinding() {
        var box = false
        let state = ControllableState(wrappedValue: false, external: Binding(get: { box }, set: { box = $0 }))

        state.projectedValue.wrappedValue = true
        XCTAssertTrue(box, "A write through the projected binding must reach the caller's binding.")
        XCTAssertTrue(state.projectedValue.wrappedValue, "The projected binding must read back the caller's value.")

        box = false
        XCTAssertFalse(state.wrappedValue, "A caller-side write must be visible through the wrapper.")
    }

    /// Controlled mode seeds from — and always reads — the binding's current
    /// value; the `wrappedValue` seed is only the uncontrolled fallback.
    @MainActor
    func testControlledReadPrefersBindingOverSeed() {
        let state = ControllableState(wrappedValue: false, external: .constant(true))
        XCTAssertTrue(state.wrappedValue, "The caller's binding must win over the uncontrolled seed.")
    }

    /// A `nil` binding funnels `init(wrappedValue:external:)` into the
    /// uncontrolled path (how optional-binding adopters use one initializer).
    @MainActor
    func testNilExternalFallsBackToUncontrolledSeed() {
        let state = ControllableState(wrappedValue: true, external: nil)
        XCTAssertTrue(state.wrappedValue, "With no binding, reads must come from the internal seed.")
    }

    // MARK: Hosted parity (uncontrolled @State only accepts writes once
    // installed in a live view graph, so these toggle inside a hosted view)

    /// An uncontrolled toggle must update the wrapper's own state and must NOT
    /// touch a binding the caller happens to hold but didn't inject.
    @MainActor
    func testUncontrolledWriteDoesNotTouchCallerBinding() {
        var box = false
        _ = Binding(get: { box }, set: { box = $0 }) // exists at the call site, never injected

        var observed: [Bool] = []
        host(ToggleHarness(external: nil) { observed.append($0) })

        XCTAssertEqual(observed, [true], "An uncontrolled toggle must update the wrapper's internal state.")
        XCTAssertFalse(box, "An uncontrolled write must never reach a caller-side binding.")
    }

    /// One tap toggles `false -> true` in both modes: uncontrolled lands in the
    /// internal @State, controlled lands in the caller's binding — same result.
    @MainActor
    func testControlledAndUncontrolledTogglingReachTheSameExpandedState() {
        var observed: [Bool] = []
        host(ToggleHarness(external: nil) { observed.append($0) })
        let uncontrolledFinal = observed.last

        var box = false
        host(ToggleHarness(external: Binding(get: { box }, set: { box = $0 })))
        let controlledFinal = box

        XCTAssertEqual(uncontrolledFinal, true, "The uncontrolled toggle must reach the expanded state.")
        XCTAssertTrue(controlledFinal, "The controlled toggle must reach the expanded state.")
        XCTAssertEqual(uncontrolledFinal, controlledFinal,
                       "Controlled and uncontrolled toggling must reach the same expanded state.")
    }

    // MARK: Accordion refactor stays behavior-neutral (both public inits render
    // pixel-identically for the same expansion state)

    @MainActor
    func testAccordionControlledAndUncontrolledRenderIdentically() throws {
        func uncontrolled(_ expanded: Bool) -> some View {
            Accordion("Refund policy", initiallyExpanded: expanded) { Text("Within 14 days.") }
                .frame(width: 240)
        }
        func controlled(_ expanded: Bool) -> some View {
            Accordion("Refund policy", isExpanded: .constant(expanded)) { Text("Within 14 days.") }
                .frame(width: 240)
        }

        let openU = try pixels(uncontrolled(true)), openC = try pixels(controlled(true))
        let shutU = try pixels(uncontrolled(false)), shutC = try pixels(controlled(false))

        XCTAssertEqual(openU, openC, "Expanded: both inits must render pixel-identically.")
        XCTAssertEqual(shutU, shutC, "Collapsed: both inits must render pixel-identically.")
        XCTAssertNotEqual(openU, shutU, "Sanity: expanded and collapsed must render differently.")
    }

    @MainActor
    func testAccordionGroupControlledAndUncontrolledRenderIdentically() throws {
        struct Row: Identifiable { let id: Int; let q: String }
        let rows = [Row(id: 0, q: "One"), Row(id: 1, q: "Two")]

        let uncontrolled = AccordionGroup(rows, initiallyExpanded: [0]) { $0.q } content: { Text($0.q) }
            .frame(width: 240)
        let controlled = AccordionGroup(rows, expanded: .constant([0])) { $0.q } content: { Text($0.q) }
            .frame(width: 240)
        let collapsed = AccordionGroup(rows) { $0.q } content: { Text($0.q) }
            .frame(width: 240)

        let u = try pixels(uncontrolled), c = try pixels(controlled), shut = try pixels(collapsed)
        XCTAssertEqual(u, c, "Both group inits must render pixel-identically for the same open set.")
        XCTAssertNotEqual(u, shut, "Sanity: an open row must render differently from all-collapsed.")
    }

    // MARK: Helpers

    /// Minimal adopter: toggles once on appear, reports uncontrolled changes.
    /// (Controlled changes are asserted on the caller's binding instead — a
    /// plain-var binding doesn't invalidate the view, exactly like production
    /// call sites where the binding's own @State drives the re-render.)
    private struct ToggleHarness: View {
        @ControllableState private var expanded: Bool
        private let onChange: (Bool) -> Void

        init(external: Binding<Bool>?, onChange: @escaping (Bool) -> Void = { _ in }) {
            _expanded = ControllableState(wrappedValue: false, external: external)
            self.onChange = onChange
        }

        var body: some View {
            Color.clear
                .frame(width: 8, height: 8)
                .onAppear { expanded.toggle() }
                .onChangeCompat(of: expanded) { _, newValue in onChange(newValue) }
        }
    }

    /// Host a view in an offscreen window and pump the run loop so @State is
    /// installed and onAppear/onChange fire (mirrors GifGenerator.hostedCGImage).
    @MainActor
    private func host(_ view: some View, for duration: TimeInterval = 0.3) {
        #if canImport(AppKit)
        let hostView = NSHostingView(rootView: view)
        hostView.frame = NSRect(x: 0, y: 0, width: 8, height: 8)
        let window = NSWindow(contentRect: hostView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hostView
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
        window.orderOut(nil)
        #elseif canImport(UIKit)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        window.rootViewController = UIHostingController(rootView: view)
        window.isHidden = false
        RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
        window.isHidden = true
        #endif
    }

    /// Raw rendered pixels via ImageRenderer (host-independent; mirrors
    /// ThemeInjectionTests.pixels — same size + scale ⇒ comparable bytes).
    @MainActor
    private func pixels(_ view: some View) throws -> Data {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let cg = try XCTUnwrap(renderer.cgImage, "no render")
        return try XCTUnwrap(cg.dataProvider?.data, "no backing data") as Data
    }
}
