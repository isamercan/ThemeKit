//
//  OTPInput.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference OTPInputView. A row of digit
//  boxes backed by a single hidden field, with focus caret + error state.
//

import SwiftUI

public struct OTPInput: View {
    @Binding private var code: String
    private let digitCount: Int
    private let messages: [InfoMessage]
    private let accessibilityID: String?
    private let isEnabled: Bool

    @FocusState private var isFocused: Bool

    public init(
        code: Binding<String>,
        digitCount: Int = 6,
        errorText: String? = nil,
        infoMessages: [InfoMessage] = [],
        accessibilityID: String? = nil,
        isEnabled: Bool = true
    ) {
        self._code = code
        self.digitCount = digitCount
        var messages = infoMessages
        if let errorText { messages.append(InfoMessage(errorText, kind: .error)) }
        self.messages = messages
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
    }

    private var hasError: Bool { messages.dominantKind == .error }

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
                            isEnabled: isEnabled
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
                        code = String(newValue.filter(\.isNumber).prefix(digitCount))
                    }
                    .a11y(A11yElement.Field.field, in: accessibilityID)
                    .accessibilityLabel(String(themeKit: "Verification code"))
                    .accessibilityValue(code)
            }

            if !messages.isEmpty {
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
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
    let digit: String
    let isActive: Bool
    let isFilled: Bool
    let hasError: Bool
    let isEnabled: Bool

    @State private var caretOn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .fill(Theme.shared.background(isEnabled ? .bgWhite : .bgSecondaryLight))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isActive || hasError ? 1.5 : 1)
                )
                // Fixed height: the box is a square cell in a fixed-width grid;
                // Dynamic Type is capped at the container via dynamicTypeClamp().
                .frame(height: 56)

            if digit.isEmpty, isActive {
                Rectangle()
                    .fill(Theme.shared.foreground(.fgHero))
                    .frame(width: 2, height: 24)
                    .opacity(reduceMotion ? 1 : (caretOn ? 1 : 0))
                    .onAppear {
                        // Honor Reduce Motion: a solid caret, no blink.
                        guard !reduceMotion else { return }
                        withAnimation(Motion.slower.animation.repeatForever()) { caretOn = true }
                    }
            } else {
                Text(digit)
                    .textStyle(.headingBase)
                    .foregroundStyle(textColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var borderColor: Color {
        if hasError { return Theme.shared.border(.systemcolorsBorderError) }
        if isActive || isFilled { return Theme.shared.border(.borderHero) }
        return Theme.shared.border(.borderPrimary)
    }

    private var textColor: Color {
        if !isEnabled { return Theme.shared.text(.textDisabled) }
        if hasError { return Theme.shared.foreground(.systemcolorsFgError) }
        return Theme.shared.text(.textPrimary)
    }
}

#Preview {
    struct Demo: View {
        @State var code = "123"
        var body: some View {
            VStack(spacing: 24) {
                OTPInput(code: $code)
                OTPInput(code: .constant("12"), digitCount: 4, errorText: "Invalid code")
            }
            .padding()
        }
    }
    return Demo()
}
