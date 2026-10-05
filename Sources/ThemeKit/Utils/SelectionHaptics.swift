//
//  SelectionHaptics.swift
//  ThemeKit
//  Created by İsa Mercan on 05.10.2026.
//
//  An opt-in selection tick on ThemeKit's choice controls — `ThemeToggle`, `Checkbox` and
//  `RadioButton` — when the user changes their value. Off by default, so an app's feel doesn't
//  change under it; a design system that wants it (Ucuzabilet's, matching its Android app) turns it
//  on for its subtree. Buttons keep their own press tap (`Haptics.tap()`).
//
//    FormView().selectionHaptics(true)
//

import SwiftUI

private struct SelectionHapticsKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether choice controls tick when their value changes. `false` by default.
    var selectionHaptics: Bool {
        get { self[SelectionHapticsKey.self] }
        set { self[SelectionHapticsKey.self] = newValue }
    }
}

public extension View {
    /// Turns the selection tick of `ThemeToggle`, `Checkbox` and `RadioButton` on or off for this
    /// view and its children.
    func selectionHaptics(_ enabled: Bool) -> some View {
        environment(\.selectionHaptics, enabled)
    }
}
