//
//  ReadOnly.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A kit-wide read-only axis (HeroUI `isReadOnly` / Ant `readOnly`). Unlike
//  `.disabled(_:)` — which dims to the disabled token and drops the control from
//  the a11y value tree — a read-only input keeps its NORMAL chrome and its
//  VoiceOver value, but suppresses editing, focus and clear/reveal affordances.
//  It's the right axis for review / summary / confirmation screens where the
//  data must stay legible and copy-able but not editable.
//
//  Components opt in by reading `\.isReadOnly` and gating their editing surface
//  (make the inner control non-focusable / non-editable, hide clear buttons,
//  keep the value text and border). Presentation stays identical to the
//  editable state.
//

import SwiftUI

private struct IsReadOnlyKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether inputs in this subtree are read-only (non-editable but not
    /// disabled). Read by the field family; set with `.readOnly(_:)`.
    var isReadOnly: Bool {
        get { self[IsReadOnlyKey.self] }
        set { self[IsReadOnlyKey.self] = newValue }
    }
}

public extension View {
    /// Mark inputs in this subtree read-only: they render their value with the
    /// normal (non-dimmed) chrome but can't be edited, focused, or cleared.
    /// VoiceOver still reads the value. Distinct from `.disabled(_:)`.
    ///
    ///     ReviewForm()
    ///         .readOnly(isSubmitted)
    func readOnly(_ on: Bool = true) -> some View {
        environment(\.isReadOnly, on)
    }
}
