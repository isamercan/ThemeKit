//
//  Buttons.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Themed button family. All colors resolve from the active theme
//  (ADR-0001: no hardcoded colors in components).
//

import SwiftUI

public enum GlobalButtonStyle {
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
    enum Phase { case idle, running, success }

    let title: String
    let helperText: String?
    let textStyle: TextStyle?
    let style: GlobalButtonStyle
    let size: ButtonSize
    let isContentWidth: Bool
    let confirmsSuccess: Bool
    let accessibilityID: String?
    @Binding var isEnabled: Bool
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
                    .foregroundStyle(Theme.shared.text(.textTertiary))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: isContentWidth ? nil : .infinity)
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
                        .transition(.opacity)
                }
            }
            .frame(height: size.height)
            .frame(maxWidth: isContentWidth ? nil : .infinity)
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
        guard isEnabled else { return Theme.shared.text(.textDisabled) }
        switch style {
        case .primary: return Theme.shared.foreground(.fgSecondary)   // white
        case .secondary, .outline, .ghost, .link: return Theme.shared.text(.textHero)
        }
    }

    private var background: Color {
        switch style {
        case .primary:
            return Theme.shared.background(isEnabled ? .bgHero : .bgSecondary)
        case .secondary:
            return Theme.shared.background(.bgWhite)
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
                .stroke(Theme.shared.border(isEnabled ? .borderHero : .borderPrimary), lineWidth: 1)
        }
    }
}

// MARK: - Public button types

public struct PrimaryButton: View {
    private let configuration: ButtonConfiguration

    public init(
        _ title: String,
        size: ButtonSize = .medium,
        isContentWidth: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = false,
        accessibilityID: String? = nil,
        isEnabled: Binding<Bool> = .constant(true),
        isLoading: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .primary, size: size, isContentWidth: isContentWidth,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: isLoading, run: { action() }
        )
    }

    /// Async action: shows an automatic loading spinner while the task runs, then
    /// (optionally) a success checkmark. Tap haptic + success haptic included.
    public init(
        _ title: String,
        size: ButtonSize = .medium,
        isContentWidth: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = true,
        accessibilityID: String? = nil,
        isEnabled: Binding<Bool> = .constant(true),
        task: @escaping () async -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .primary, size: size, isContentWidth: isContentWidth,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: .constant(false), run: task
        )
    }

    public var body: some View { configuration.view }
}

public struct SecondaryButton: View {
    private let configuration: ButtonConfiguration

    public init(
        _ title: String,
        size: ButtonSize = .medium,
        isContentWidth: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = false,
        accessibilityID: String? = nil,
        isEnabled: Binding<Bool> = .constant(true),
        isLoading: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .secondary, size: size, isContentWidth: isContentWidth,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: isLoading, run: { action() }
        )
    }

    /// Async action with automatic loading + optional success confirmation.
    public init(
        _ title: String,
        size: ButtonSize = .medium,
        isContentWidth: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = true,
        accessibilityID: String? = nil,
        isEnabled: Binding<Bool> = .constant(true),
        task: @escaping () async -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .secondary, size: size, isContentWidth: isContentWidth,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: .constant(false), run: task
        )
    }

    public var body: some View { configuration.view }
}

public struct OutlineButton: View {
    private let configuration: ButtonConfiguration

    public init(
        _ title: String,
        size: ButtonSize = .medium,
        isContentWidth: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = false,
        accessibilityID: String? = nil,
        isEnabled: Binding<Bool> = .constant(true),
        isLoading: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .outline, size: size, isContentWidth: isContentWidth,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: isLoading, run: { action() }
        )
    }

    /// Async action with automatic loading + optional success confirmation.
    public init(
        _ title: String,
        size: ButtonSize = .medium,
        isContentWidth: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = true,
        accessibilityID: String? = nil,
        isEnabled: Binding<Bool> = .constant(true),
        task: @escaping () async -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .outline, size: size, isContentWidth: isContentWidth,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: .constant(false), run: task
        )
    }

    public var body: some View { configuration.view }
}

public struct GhostButton: View {
    private let configuration: ButtonConfiguration

    public init(
        _ title: String,
        size: ButtonSize = .medium,
        isContentWidth: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = false,
        accessibilityID: String? = nil,
        isEnabled: Binding<Bool> = .constant(true),
        isLoading: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .ghost, size: size, isContentWidth: isContentWidth,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: isLoading, run: { action() }
        )
    }

    /// Async action with automatic loading + optional success confirmation.
    public init(
        _ title: String,
        size: ButtonSize = .medium,
        isContentWidth: Bool = false,
        helperText: String? = nil,
        textStyle: TextStyle? = nil,
        confirmsSuccess: Bool = true,
        accessibilityID: String? = nil,
        isEnabled: Binding<Bool> = .constant(true),
        task: @escaping () async -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, helperText: helperText, textStyle: textStyle,
            style: .ghost, size: size, isContentWidth: isContentWidth,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: .constant(false), run: task
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
        isEnabled: Binding<Bool> = .constant(true),
        action: @escaping () -> Void
    ) {
        configuration = ButtonConfiguration(
            title: title, style: .link, size: size, isContentWidth: true,
            accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: .constant(false), run: { action() }
        )
    }

    public var body: some View { configuration.view }
}

// MARK: - Internal config

private struct ButtonConfiguration {
    let title: String
    var helperText: String? = nil
    var textStyle: TextStyle? = nil
    let style: GlobalButtonStyle
    let size: ButtonSize
    let isContentWidth: Bool
    var confirmsSuccess: Bool = false
    let accessibilityID: String?
    let isEnabled: Binding<Bool>
    let isLoading: Binding<Bool>
    let run: () async -> Void

    // Only ever read from a preset's `body` (main actor), so building the
    // main-actor `ThemedButton` here is in-context — avoids sending the async
    // `run` closure across isolation.
    @MainActor var view: some View {
        ThemedButton(
            title: title, helperText: helperText, textStyle: textStyle,
            style: style, size: size, isContentWidth: isContentWidth,
            confirmsSuccess: confirmsSuccess, accessibilityID: accessibilityID,
            isEnabled: isEnabled, isLoading: isLoading, run: run
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("Primary", isContentWidth: true) {}
        SecondaryButton("Secondary", isContentWidth: true) {}
        OutlineButton("Outline", isContentWidth: true) {}
        PrimaryButton("Disabled", isContentWidth: true, isEnabled: .constant(false)) {}
        PrimaryButton("Loading", isContentWidth: true, isLoading: .constant(true)) {}
    }
    .padding()
    .environmentObject(Theme.shared)
}
