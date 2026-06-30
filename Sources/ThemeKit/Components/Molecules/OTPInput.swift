//
//  OTPInput.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Improved, token-bound rewrite of the reference OTPInputView. A row of digit
/// boxes backed by a single hidden field, with focus caret + error state.
public struct OTPInput: View {
    @Environment(\.theme) private var theme

    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`

    // Appearance/content/state — mutated only through the modifiers below (R2).
    private var digitCount: Int = 6
    private var isSecure = false
    private var errorText: String?
    private var infoMessages: [InfoMessage] = []
    private var accessibilityID: String?
    private var resendInterval: TimeInterval?
    private var onResend: (() -> Void)?

    @Binding private var code: String
    private let onComplete: ((String) -> Void)?

    @FocusState private var isFocused: Bool
    @State private var lastFired = ""
    @State private var secondsLeft = 0
    @State private var resendID = 0

    public init(code: Binding<String>, onComplete: ((String) -> Void)? = nil) {   // R1
        self._code = code
        self.onComplete = onComplete
    }

    /// Validation/hint lines: `infoMessages` plus the optional `errorText` (appended as `.error`).
    private var messages: [InfoMessage] {
        var messages = infoMessages
        if let errorText { messages.append(InfoMessage(errorText, kind: .error)) }
        return messages
    }

    private var hasError: Bool { messages.dominantKind == .error }

    /// Keeps only digits and caps the length (extracted for testing).
    static func sanitize(_ raw: String, digitCount: Int) -> String {
        String(raw.filter(\.isNumber).prefix(digitCount))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            ZStack {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    ForEach(0..<digitCount, id: \.self) { index in
                        OTPDigitBox(
                            digit: digit(at: index),
                            isActive: isFocused && code.count == index,
                            isFilled: index < code.count,
                            hasError: hasError,
                            isEnabled: isEnabled,
                            isSecure: isSecure
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { if isEnabled { isFocused = true } }
                // The boxes are a decorative mirror of the field's value; the
                // hidden TextField below carries the real VoiceOver element, so
                // hide the per-digit glyphs to avoid duplicate announcements.
                .accessibilityHidden(true)
                // A fixed-width digit grid can't grow horizontally, so cap text
                // scaling instead of stretching the boxes out of proportion.
                .dynamicTypeClamp()

                TextField("", text: $code)
                    .focused($isFocused)
                    .otpKeyboard()
                    .opacity(0.001)
                    .frame(width: 1, height: 1)
                    .disabled(!isEnabled)
                    .onChange(of: code) { _, newValue in
                        let sanitized = Self.sanitize(newValue, digitCount: digitCount)
                        if sanitized != code { code = sanitized }
                        if sanitized.count == digitCount {
                            // Fire once per completion; re-arms after an edit.
                            if sanitized != lastFired {
                                lastFired = sanitized
                                if onComplete != nil {
                                    isFocused = false
                                    onComplete?(sanitized)
                                }
                            }
                        } else {
                            lastFired = ""
                        }
                    }
                    .a11y(A11yElement.Field.field, in: accessibilityID)
                    .accessibilityLabel(String(themeKit: "Verification code"))
                    .accessibilityValue(code)
            }

            if !messages.isEmpty {
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
            }

            if let resendInterval, let onResend {
                resendRow(interval: resendInterval, onResend: onResend)
            }
        }
    }

    @ViewBuilder
    private func resendRow(interval: TimeInterval, onResend: @escaping () -> Void) -> some View {
        Group {
            if secondsLeft > 0 {
                Text(String(themeKit: "Resend code in \(secondsLeft)s"))
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
            } else {
                Button {
                    onResend()
                    resendID += 1   // restarts the countdown task
                } label: {
                    Text(String(themeKit: "Resend code"))
                        .textStyle(.labelSm700)
                        .foregroundStyle(theme.text(.textHero))
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
            }
        }
        .task(id: resendID) {
            secondsLeft = Int(interval)
            while secondsLeft > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                secondsLeft -= 1
            }
        }
    }

    private func digit(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(Array(code)[index])
    }
}

private extension View {
    /// Applies numeric / one-time-code keyboard traits (iOS only).
    @ViewBuilder
    func otpKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad).textContentType(.oneTimeCode)
        #else
        self
        #endif
    }
}

private struct OTPDigitBox: View {
    @Environment(\.theme) private var theme

    let digit: String
    let isActive: Bool
    let isFilled: Bool
    let hasError: Bool
    let isEnabled: Bool
    let isSecure: Bool

    @State private var caretOn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .fill(theme.background(isEnabled ? .bgWhite : .bgSecondaryLight))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isActive || hasError ? 1.5 : 1)
                )
                // Fixed height: the box is a square cell in a fixed-width grid;
                // Dynamic Type is capped at the container via dynamicTypeClamp().
                .frame(height: 56)

            if digit.isEmpty {
                if isActive {
                    Rectangle()
                        .fill(theme.foreground(.fgHero))
                        .frame(width: 2, height: 24)
                        .opacity(reduceMotion ? 1 : (caretOn ? 1 : 0))
                        .onAppear {
                            // Honor Reduce Motion: a solid caret, no blink.
                            guard !reduceMotion else { return }
                            withAnimation(Motion.slower.animation.repeatForever()) { caretOn = true }
                        }
                }
            } else {
                Text(isSecure ? "●" : digit)
                    .textStyle(.headingBase)
                    .foregroundStyle(textColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var borderColor: Color {
        if hasError { return theme.border(.systemcolorsBorderError) }
        if isActive || isFilled { return theme.border(.borderHero) }
        return theme.border(.borderPrimary)
    }

    private var textColor: Color {
        if !isEnabled { return theme.text(.textDisabled) }
        if hasError { return theme.foreground(.systemcolorsFgError) }
        return theme.text(.textPrimary)
    }
}

#Preview {
    struct Demo: View {
        @State var code = "123"
        @State var lastComplete = "—"
        var body: some View {
            VStack(spacing: 24) {
                OTPInput(code: $code, onComplete: { lastComplete = $0 }).resend(interval: 30, onResend: {})
                Text("Completed: \(lastComplete)").textStyle(.bodySm400)
                OTPInput(code: .constant("4321")).digitCount(4).secure()
                OTPInput(code: .constant("12")).digitCount(4).errorText("Invalid code")
            }
            .padding()
        }
    }
    return Demo()
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension OTPInput {
    /// Number of digit boxes (default 6).
    func digitCount(_ n: Int) -> Self { copy { $0.digitCount = n } }

    /// Mask the entered digits (password-style dots) instead of showing them.
    func secure(_ on: Bool = true) -> Self { copy { $0.isSecure = on } }

    /// Inline error line (appended to `infoMessages` as `.error`, driving the error state).
    func errorText(_ text: String?) -> Self { copy { $0.errorText = text } }

    /// Validation / hint messages displayed below the boxes.
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Adds a countdown + "resend code" row. `interval` seconds before re-enabling.
    func resend(interval: TimeInterval, onResend: @escaping () -> Void) -> Self {
        copy { $0.resendInterval = interval; $0.onResend = onResend }
    }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
