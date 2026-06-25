//
//  Accessibility.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Accessibility identifier system (UI tests + VoiceOver), modeled on the
//  reference's `UIElements+…` element ids + `accessibilityPrefix`. A component
//  takes an `accessibilityID` namespace; its sub-elements get a stable,
//  namespaced identifier via `.a11y(_:in:)`.
//
//      TextInput("Email", text: $t, accessibilityID: "loginEmail")
//      // field → "loginEmail.field", clear button → "loginEmail.clear"
//

import SwiftUI

/// Stable sub-element names used by components for accessibility identifiers.
public enum A11yElement {
    public enum Field: String { case field, secureField, clear, reveal, label, message }
    public enum Control: String { case toggle, checkbox, radio, stepper, slider }
    public enum Action: String { case button, primary, secondary, close, back }
    public enum Select: String { case trigger, option, search, tag }
}

public extension View {
    /// Namespaced accessibility identifier (`"<namespace>.<element>"`). No-op when
    /// `namespace` is nil so unlabeled instances don't collide in UI tests.
    @ViewBuilder
    func a11y(_ element: String, in namespace: String?) -> some View {
        if let namespace { accessibilityIdentifier("\(namespace).\(element)") } else { self }
    }

    /// Convenience for the `A11yElement` enums.
    func a11y<E: RawRepresentable>(_ element: E, in namespace: String?) -> some View where E.RawValue == String {
        a11y(element.rawValue, in: namespace)
    }
}
