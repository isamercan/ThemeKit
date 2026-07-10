//
//  ControllableState.swift
//  ThemeKit
//
//  One reusable DynamicProperty for the library's controlled/uncontrolled state
//  pattern (ADR-4): every stateful component works uncontrolled by default
//  (`initiallyX:` seeds private @State) and controlled on demand (an overload
//  takes `x: Binding<…>` and the caller owns the state). Extracted from the
//  Accordion fallback dance so adopters don't re-implement it.
//

import SwiftUI

/// Unifies the *uncontrolled* (`@State`-seeded) and *controlled* (`Binding`-driven)
/// paths of a component's interaction state behind one accessor.
///
/// - **Uncontrolled** — `init(wrappedValue:)` (or a `nil` `external`): the initial
///   value seeds internal `@State`; the component owns its state and the caller
///   gets the drop-in API (`Accordion("Title", initiallyExpanded: true) { … }`).
/// - **Controlled** — `init(wrappedValue:external:)` with a binding: reads and
///   writes flow through the caller's `Binding`, so the caller owns, observes and
///   can drive the state (`Accordion("Title", isExpanded: $open) { … }`). There is
///   no `onChange`-style callback pair — the `Binding` *is* the change channel;
///   observers use `.onChange(of:)` at the call site.
///
/// Hand `$value` (the projected `Binding`) to child views and gestures exactly
/// like a normal binding; it routes to whichever storage is live.
///
/// **The one rule:** don't switch a live view between controlled and uncontrolled
/// across renders. The captured binding is fixed at `init`, and the internal
/// `@State` would rejoin at its old value — pick one mode per view identity
/// (each of a component's dual inits is one mode, so normal call sites can't
/// get this wrong).
@propertyWrapper
public struct ControllableState<Value>: DynamicProperty {
    @State private var stored: Value
    private let external: Binding<Value>?

    /// Uncontrolled: the initial value seeds internal `@State`.
    public init(wrappedValue: Value) {
        _stored = State(initialValue: wrappedValue)
        external = nil
    }

    /// Controlled: reads/writes flow through the caller's binding. A `nil`
    /// binding falls back to the uncontrolled path, so optional-binding
    /// adopters can funnel both modes through this one initializer.
    public init(wrappedValue: Value, external: Binding<Value>?) {
        _stored = State(initialValue: external?.wrappedValue ?? wrappedValue)
        self.external = external
    }

    @MainActor
    public var wrappedValue: Value {
        get { external?.wrappedValue ?? stored }
        nonmutating set {
            if let external { external.wrappedValue = newValue } else { stored = newValue }
        }
    }

    /// Hand to child views / gestures exactly like a normal binding.
    @MainActor
    public var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
