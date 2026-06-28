//
//  Buttons.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Themed button family. All colors resolve from the active theme
//  (ADR-0001: no hardcoded colors in components).
//

import SwiftUI

public enum ThemeButtonStyle {
    case primary
    case secondary
    case outline
    case ghost
    case link
}

/// Shared themed button core used by the public button types. Handles tactile
/// haptics, an async `run` with an automatic loading spinner, and an optional
/// success-confirmation that morphs the label into a checkmark.
private struct ThemedButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`

    enum Phase { case idle, running, success }

    let title: String
    let helperText: String?
    let textStyle: TextStyle?
    let style: ThemeButtonStyle
    let size: ButtonSize
    let block: Bool
    let confirmsSuccess: Bool
    let accessibilityID: String?
    @Binding var isLoading: Bool
    let run: () async -> Void

    @State private var phase: Phase = .idle

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
                        .font(.system(size: size.fontSize + 2, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(title)
                        .textStyle(textStyle ?? size.textStyle)
                        .underline(style == .link)
                        .lineLimit(1)              // a button label stays on one line (truncates, never wraps)
                        .transition(.opacity)
                }
            }
            .frame(height: size.height)
            .frame(maxWidth: block ? .infinity : nil)
            .padding(.horizontal, size.horizontalPadding)
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
        case .primary: return theme.foreground(.fgSecondary)   // white
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
    private let configuration: ButtonConfiguration

    public init(
        _ title: String,
        size: ButtonSize = .medium,
        block: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = false,
        accessibilityID: String? = nil,
        isLoading: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .primary, size: size, block: block,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isLoading: isLoading, run: { action() }
        )
    }

    /// Async action: shows an automatic loading spinner while the task runs, then
    /// (optionally) a success checkmark. Tap haptic + success haptic included.
    public init(
        _ title: String,
        size: ButtonSize = .medium,
        block: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = true,
        accessibilityID: String? = nil,
        task: @escaping () async -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .primary, size: size, block: block,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isLoading: .constant(false), run: task
        )
    }

    public var body: some View { configuration.view }
}

public struct SecondaryButton: View {
    private let configuration: ButtonConfiguration

    public init(
        _ title: String,
        size: ButtonSize = .medium,
        block: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = false,
        accessibilityID: String? = nil,
        isLoading: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .secondary, size: size, block: block,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isLoading: isLoading, run: { action() }
        )
    }

    /// Async action with automatic loading + optional success confirmation.
    public init(
        _ title: String,
        size: ButtonSize = .medium,
        block: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = true,
        accessibilityID: String? = nil,
        task: @escaping () async -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .secondary, size: size, block: block,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isLoading: .constant(false), run: task
        )
    }

    public var body: some View { configuration.view }
}

public struct OutlineButton: View {
    private let configuration: ButtonConfiguration

    public init(
        _ title: String,
        size: ButtonSize = .medium,
        block: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = false,
        accessibilityID: String? = nil,
        isLoading: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .outline, size: size, block: block,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isLoading: isLoading, run: { action() }
        )
    }

    /// Async action with automatic loading + optional success confirmation.
    public init(
        _ title: String,
        size: ButtonSize = .medium,
        block: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = true,
        accessibilityID: String? = nil,
        task: @escaping () async -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .outline, size: size, block: block,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isLoading: .constant(false), run: task
        )
    }

    public var body: some View { configuration.view }
}

public struct GhostButton: View {
    private let configuration: ButtonConfiguration

    public init(
        _ title: String,
        size: ButtonSize = .medium,
        block: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = false,
        accessibilityID: String? = nil,
        isLoading: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .ghost, size: size, block: block,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isLoading: isLoading, run: { action() }
        )
    }

    /// Async action with automatic loading + optional success confirmation.
    public init(
        _ title: String,
        size: ButtonSize = .medium,
        block: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = true,
        accessibilityID: String? = nil,
        task: @escaping () async -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .ghost, size: size, block: block,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isLoading: .constant(false), run: task
        )
    }

    public var body: some View { configuration.view }
}

public struct LinkButton: View {
    private let configuration: ButtonConfiguration

    public init(
        _ title: String,
        size: ButtonSize = .medium,
        accessibilityID: String? = nil,
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, style: .link, size: size, block: false,
            accessibilityID: accessibilityID,
            isLoading: .constant(false), run: { action() }
        )
    }

    public var body: some View { configuration.view }
}

// MARK: - Internal config

private struct ButtonConfiguration {
    let title: String
    var helperText: String? = nil
    var textStyle: TextStyle? = nil
    let style: ThemeButtonStyle
    let size: ButtonSize
    let block: Bool
    var confirmsSuccess: Bool = false
    let accessibilityID: String?
    let isLoading: Binding<Bool>
    let run: () async -> Void

    // Only ever read from a preset's `body` (main actor), so building the
    // main-actor `ThemedButton` here is in-context — avoids sending the async
    // `run` closure across isolation.
    @MainActor var view: some View {
        ThemedButton(
            title: title, helperText: helperText, textStyle: textStyle,
            style: style, size: size, block: block,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isLoading: isLoading, run: run
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Primary") {}
        SecondaryButton("Secondary") {}
        OutlineButton("Outline") {}
        PrimaryButton("Disabled") {}.disabled(true)
        PrimaryButton("Loading", isLoading: .constant(true)) {}
        PrimaryButton("Full-width CTA", block: true) {}
    }
    .padding()
    .environment(Theme.shared)
}
