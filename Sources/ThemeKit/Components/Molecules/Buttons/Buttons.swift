//
//  Buttons.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Themed button family. All colors resolve from the active theme
//  (ADR-0001: no hardcoded colors in components).
//
//  Per the modifier-based architecture (COMPONENT_REFACTOR_RULES R1–R7) each
//  preset's init takes only its content + action (sync `action:` or async
//  `task:`); every appearance/state axis is a chainable, order-free modifier.
//  `disabled` is native (`@Environment(\.isEnabled)`, R3).
//
//      PrimaryButton("Book") { await book() }
//          .size(.large).fullWidth().helperText("No charge yet")
//          .disabled(!formValid)            // native — R3
//

import SwiftUI

public enum ThemeButtonStyle {
    case primary
    case secondary
    case outline
    case ghost
    case link
}

/// Whether a preset button was created with a sync `action` or an async `task`.
/// Drives the default for `confirmsSuccess` (task-based buttons confirm by
/// default; action-based don't) when no explicit `.confirmsSuccess(_:)` is set.
private enum ButtonRunMode {
    case action, task
}

/// Shared themed button core used by the public button types. Handles tactile
/// haptics, an async `run` with an automatic loading spinner, and an optional
/// success-confirmation that morphs the label into a checkmark.
private struct ThemedButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    @Environment(\.buttonGroupControlSize) private var groupSize   // set by an enclosing sized `ButtonGroup`

    enum Phase { case idle, running, success }

    let title: String
    let helperText: String?
    let textStyle: TextStyle?
    let style: ThemeButtonStyle
    /// `nil` defers to an enclosing sized ``ButtonGroup``, then `.medium`.
    let size: ButtonSize?
    let block: Bool
    let confirmsSuccess: Bool
    let accessibilityID: String?
    let isLoading: Bool
    let run: () async -> Void

    @State private var phase: Phase = .idle

    /// Explicit preset `.size(_:)` ?? enclosing `ButtonGroup` size ?? `.medium`.
    private var resolvedSize: ButtonSize { size ?? groupSize ?? .medium }
    private var showsSpinner: Bool { isLoading || phase == .running }

    var body: some View {
        VStack(spacing: 2) {
            button
            if let helperText {
                Text(helperText)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: block ? .infinity : nil)
    }

    private var button: some View {
        Button {
            guard phase == .idle, !isLoading else { return }
            Haptics.tap()
            Task { @MainActor in
                phase = .running
                await run()
                if confirmsSuccess {
                    phase = .success
                    Haptics.success()
                    try? await Task.sleep(nanoseconds: 1_100_000_000)
                }
                phase = .idle
            }
        } label: {
            ZStack {
                if showsSpinner {
                    ProgressView().tint(foreground)
                        .transition(.scale.combined(with: .opacity))
                } else if phase == .success {
                    Image(systemName: "checkmark")
                        .font(.system(size: resolvedSize.fontSize + 2, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(title)
                        .textStyle(textStyle ?? resolvedSize.textStyle)
                        .underline(style == .link)
                        .lineLimit(1)              // a button label stays on one line (truncates, never wraps)
                        .transition(.opacity)
                }
            }
            .frame(height: resolvedSize.height)
            .frame(maxWidth: block ? .infinity : nil)
            .padding(.horizontal, resolvedSize.horizontalPadding)
            .foregroundStyle(foreground)
            .background(background)
            .cornerRadius(.base)
            .overlay(border)
            .contentShape(Rectangle())
            .animation(Motion.fast.animation, value: phase)
            .animation(Motion.fast.animation, value: isLoading)
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(!isEnabled || phase != .idle)
        .a11y(A11yElement.Action.button, in: accessibilityID)
        .accessibilityLabel(title)
    }

    private var foreground: Color {
        guard isEnabled else { return theme.text(.textDisabled) }
        switch style {
        case .primary: return theme.resolve(.primary).onSolid   // auto-contrast on the primary fill
        case .secondary, .outline, .ghost, .link: return theme.text(.textHero)
        }
    }

    private var background: Color {
        switch style {
        case .primary:
            return theme.background(isEnabled ? .bgHero : .bgSecondary)
        case .secondary:
            return theme.background(.bgWhite)
        case .outline, .ghost, .link:
            return .clear
        }
    }

    @ViewBuilder
    private var border: some View {
        switch style {
        case .primary, .ghost, .link:
            EmptyView()
        case .secondary, .outline:
            RoundedRectangle(cornerRadius: Theme.RadiusKey.base.value, style: .continuous)
                .stroke(theme.border(isEnabled ? .borderHero : .borderPrimary), lineWidth: 1)
        }
    }
}

// MARK: - Public button types

public struct PrimaryButton: View {
    private let title: String
    private let run: () async -> Void
    private let mode: ButtonRunMode

    // Appearance/config — mutated only through the modifiers below (R2).
    /// `nil` defers to an enclosing sized ``ButtonGroup``, then `.medium`.
    private var size: ButtonSize?
    private var block = false
    private var helperText: String?
    private var titleTextStyle: TextStyle?
    private var confirmsSuccess: Bool?   // nil = unset → defaults by run mode (action: false, task: true)
    private var accessibilityID: String?
    private var isLoading = false

    public init(_ title: String, action: @escaping () -> Void) {   // R1
        self.title = title
        self.run = { action() }
        self.mode = .action
    }

    /// Async action: shows an automatic loading spinner while the task runs, then
    /// (by default) a success checkmark. Tap haptic + success haptic included.
    public init(_ title: String, task: @escaping () async -> Void) {   // R1
        self.title = title
        self.run = task
        self.mode = .task
    }

    public var body: some View {
        ThemedButton(
            title: title, helperText: helperText, textStyle: titleTextStyle,
            style: .primary, size: size, block: block,
            confirmsSuccess: confirmsSuccess ?? (mode == .task),
            accessibilityID: accessibilityID,
            isLoading: isLoading, run: run
        )
    }
}

public struct SecondaryButton: View {
    private let title: String
    private let run: () async -> Void
    private let mode: ButtonRunMode

    // Appearance/config — mutated only through the modifiers below (R2).
    /// `nil` defers to an enclosing sized ``ButtonGroup``, then `.medium`.
    private var size: ButtonSize?
    private var block = false
    private var helperText: String?
    private var titleTextStyle: TextStyle?
    private var confirmsSuccess: Bool?   // nil = unset → defaults by run mode (action: false, task: true)
    private var accessibilityID: String?
    private var isLoading = false

    public init(_ title: String, action: @escaping () -> Void) {   // R1
        self.title = title
        self.run = { action() }
        self.mode = .action
    }

    /// Async action with automatic loading + (by default) success confirmation.
    public init(_ title: String, task: @escaping () async -> Void) {   // R1
        self.title = title
        self.run = task
        self.mode = .task
    }

    public var body: some View {
        ThemedButton(
            title: title, helperText: helperText, textStyle: titleTextStyle,
            style: .secondary, size: size, block: block,
            confirmsSuccess: confirmsSuccess ?? (mode == .task),
            accessibilityID: accessibilityID,
            isLoading: isLoading, run: run
        )
    }
}

public struct OutlineButton: View {
    private let title: String
    private let run: () async -> Void
    private let mode: ButtonRunMode

    // Appearance/config — mutated only through the modifiers below (R2).
    /// `nil` defers to an enclosing sized ``ButtonGroup``, then `.medium`.
    private var size: ButtonSize?
    private var block = false
    private var helperText: String?
    private var titleTextStyle: TextStyle?
    private var confirmsSuccess: Bool?   // nil = unset → defaults by run mode (action: false, task: true)
    private var accessibilityID: String?
    private var isLoading = false

    public init(_ title: String, action: @escaping () -> Void) {   // R1
        self.title = title
        self.run = { action() }
        self.mode = .action
    }

    /// Async action with automatic loading + (by default) success confirmation.
    public init(_ title: String, task: @escaping () async -> Void) {   // R1
        self.title = title
        self.run = task
        self.mode = .task
    }

    public var body: some View {
        ThemedButton(
            title: title, helperText: helperText, textStyle: titleTextStyle,
            style: .outline, size: size, block: block,
            confirmsSuccess: confirmsSuccess ?? (mode == .task),
            accessibilityID: accessibilityID,
            isLoading: isLoading, run: run
        )
    }
}

public struct GhostButton: View {
    private let title: String
    private let run: () async -> Void
    private let mode: ButtonRunMode

    // Appearance/config — mutated only through the modifiers below (R2).
    /// `nil` defers to an enclosing sized ``ButtonGroup``, then `.medium`.
    private var size: ButtonSize?
    private var block = false
    private var helperText: String?
    private var titleTextStyle: TextStyle?
    private var confirmsSuccess: Bool?   // nil = unset → defaults by run mode (action: false, task: true)
    private var accessibilityID: String?
    private var isLoading = false

    public init(_ title: String, action: @escaping () -> Void) {   // R1
        self.title = title
        self.run = { action() }
        self.mode = .action
    }

    /// Async action with automatic loading + (by default) success confirmation.
    public init(_ title: String, task: @escaping () async -> Void) {   // R1
        self.title = title
        self.run = task
        self.mode = .task
    }

    public var body: some View {
        ThemedButton(
            title: title, helperText: helperText, textStyle: titleTextStyle,
            style: .ghost, size: size, block: block,
            confirmsSuccess: confirmsSuccess ?? (mode == .task),
            accessibilityID: accessibilityID,
            isLoading: isLoading, run: run
        )
    }
}

public struct LinkButton: View {
    private let title: String
    private let run: () async -> Void

    // Appearance/config — mutated only through the modifiers below (R2).
    /// `nil` defers to an enclosing sized ``ButtonGroup``, then `.medium`.
    private var size: ButtonSize?
    private var accessibilityID: String?

    public init(_ title: String, action: @escaping () -> Void) {   // R1
        self.title = title
        self.run = { action() }
    }

    public var body: some View {
        ThemedButton(
            title: title, helperText: nil, textStyle: nil,
            style: .link, size: size, block: false,
            confirmsSuccess: false, accessibilityID: accessibilityID,
            isLoading: false, run: run
        )
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PrimaryButton {
    /// Control size: xxsmall … large.
    func size(_ size: ButtonSize) -> Self { copy { $0.size = size } }

    /// Stretch to the available width.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.block = on } }

    /// Caption rendered under the button.
    func helperText(_ text: String?) -> Self { copy { $0.helperText = text } }

    /// Override the title's text style (defaults to the size's style).
    func titleTextStyle(_ style: TextStyle?) -> Self { copy { $0.titleTextStyle = style } }

    /// Morph the label into a success checkmark after the action completes (default: on for `task:`, off for `action:`).
    func confirmsSuccess(_ on: Bool = true) -> Self { copy { $0.confirmsSuccess = on } }

    /// Stable accessibility identifier, forwarded to the kit's a11y infrastructure.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    /// Swap the label for a spinner and block taps while `on`.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

public extension SecondaryButton {
    /// Control size: xxsmall … large.
    func size(_ size: ButtonSize) -> Self { copy { $0.size = size } }

    /// Stretch to the available width.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.block = on } }

    /// Caption rendered under the button.
    func helperText(_ text: String?) -> Self { copy { $0.helperText = text } }

    /// Override the title's text style (defaults to the size's style).
    func titleTextStyle(_ style: TextStyle?) -> Self { copy { $0.titleTextStyle = style } }

    /// Morph the label into a success checkmark after the action completes (default: on for `task:`, off for `action:`).
    func confirmsSuccess(_ on: Bool = true) -> Self { copy { $0.confirmsSuccess = on } }

    /// Stable accessibility identifier, forwarded to the kit's a11y infrastructure.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    /// Swap the label for a spinner and block taps while `on`.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

public extension OutlineButton {
    /// Control size: xxsmall … large.
    func size(_ size: ButtonSize) -> Self { copy { $0.size = size } }

    /// Stretch to the available width.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.block = on } }

    /// Caption rendered under the button.
    func helperText(_ text: String?) -> Self { copy { $0.helperText = text } }

    /// Override the title's text style (defaults to the size's style).
    func titleTextStyle(_ style: TextStyle?) -> Self { copy { $0.titleTextStyle = style } }

    /// Morph the label into a success checkmark after the action completes (default: on for `task:`, off for `action:`).
    func confirmsSuccess(_ on: Bool = true) -> Self { copy { $0.confirmsSuccess = on } }

    /// Stable accessibility identifier, forwarded to the kit's a11y infrastructure.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    /// Swap the label for a spinner and block taps while `on`.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

public extension GhostButton {
    /// Control size: xxsmall … large.
    func size(_ size: ButtonSize) -> Self { copy { $0.size = size } }

    /// Stretch to the available width.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.block = on } }

    /// Caption rendered under the button.
    func helperText(_ text: String?) -> Self { copy { $0.helperText = text } }

    /// Override the title's text style (defaults to the size's style).
    func titleTextStyle(_ style: TextStyle?) -> Self { copy { $0.titleTextStyle = style } }

    /// Morph the label into a success checkmark after the action completes (default: on for `task:`, off for `action:`).
    func confirmsSuccess(_ on: Bool = true) -> Self { copy { $0.confirmsSuccess = on } }

    /// Stable accessibility identifier, forwarded to the kit's a11y infrastructure.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    /// Swap the label for a spinner and block taps while `on`.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

public extension LinkButton {
    /// Control size: xxsmall … large.
    func size(_ size: ButtonSize) -> Self { copy { $0.size = size } }

    /// Stable accessibility identifier, forwarded to the kit's a11y infrastructure.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Buttons") {
        PreviewCase("Primary") { PrimaryButton("Primary") {} }
        PreviewCase("Secondary") { SecondaryButton("Secondary") {} }
        PreviewCase("Outline") { OutlineButton("Outline") {} }
        PreviewCase("Ghost") { GhostButton("Ghost") {} }
        PreviewCase("Link") { LinkButton("Link") {} }
        PreviewCase("Disabled") { PrimaryButton("Disabled") {}.disabled(true) }
        PreviewCase("Loading") { PrimaryButton("Loading") {}.loading() }
        PreviewCase("Full-width CTA") { PrimaryButton("Full-width CTA") {}.fullWidth() }
        PreviewCase("Helper text") { PrimaryButton("Book now") {}.helperText("No charge yet") }
    }
    .environment(Theme.shared)
}
