//
//  OTPInput.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// The characters an ``OTPInput`` accepts. Mirrors HeroUI's
/// `REGEXP_ONLY_DIGITS` / `REGEXP_ONLY_CHARS` / `REGEXP_ONLY_DIGITS_AND_CHARS`
/// patterns; letters keep the case the user typed (HeroUI does not capitalize).
public enum OTPCharacterSet: CaseIterable, Sendable {
    case digits
    case letters
    case alphanumeric

    /// Whether `character` is permitted by this set. ASCII-only, mirroring
    /// HeroUI's REGEXP_ONLY_DIGITS / _CHARS patterns ([0-9] / [a-zA-Z]) —
    /// pasted non-ASCII numerals/letters must not reach `onComplete`.
    func allows(_ character: Character) -> Bool {
        guard character.isASCII else { return false }
        switch self {
        case .digits: return character.isNumber
        case .letters: return character.isLetter
        case .alphanumeric: return character.isNumber || character.isLetter
        }
    }
}

/// Improved, token-bound rewrite of the reference OTPInputView. A row of digit
/// boxes backed by a single hidden field, with focus caret + error state.
public struct OTPInput: View {
    @Environment(\.theme) private var theme

    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fieldDefaults) private var fieldDefaults

    // Appearance/content/state — mutated only through the modifiers below (R2).
    private var digitCount: Int = 6
    private var characterSet: OTPCharacterSet = .digits
    private var groupSizes: [Int]?
    private var placeholderText: String?
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
    private var hasWarning: Bool { messages.dominantKind == .warning }

    /// OTPInput has no `TextInputSize` modifier of its own; the subtree
    /// `FieldDefaults.size` maps onto the digit-cell height (`nil` keeps the
    /// classic 56pt `.medium` cell).
    private var explicitSize: TextInputSize?
    private var effectiveSize: TextInputSize { explicitSize ?? fieldDefaults.size ?? .medium }
    /// Message rows animate when micro-animations are on and the subtree default
    /// doesn't turn message motion off (Reduce Motion still wins inside MicroMotion).
    private var messagesAnimated: Bool { micro && (fieldDefaults.messagesAnimated ?? true) }

    /// Keeps only the characters allowed by `characters` (digits by default)
    /// and caps the length (extracted for testing).
    static func sanitize(_ raw: String, digitCount: Int, characters: OTPCharacterSet = .digits) -> String {
        String(raw.filter(characters.allows).prefix(digitCount))
    }

    /// Slot indices split into visual groups. Falls back to a single group when
    /// no `groups(_:)` were set — or when the sizes are invalid (non-positive
    /// entries, or a sum that doesn't match `digitCount`).
    private var resolvedGroups: [Range<Int>] {
        guard let groupSizes, !groupSizes.isEmpty,
              groupSizes.allSatisfy({ $0 > 0 }),
              groupSizes.reduce(0, +) == digitCount
        else { return [0..<digitCount] }
        var ranges: [Range<Int>] = []
        var start = 0
        for size in groupSizes {
            ranges.append(start..<(start + size))
            start += size
        }
        return ranges
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            ZStack {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    ForEach(Array(resolvedGroups.enumerated()), id: \.offset) { groupIndex, range in
                        // HeroUI Group/Separator anatomy: a decorative dash
                        // between groups, spaced by the row's `sm` gap.
                        if groupIndex > 0 { OTPGroupSeparator() }
                        ForEach(range, id: \.self) { index in
                            OTPDigitBox(
                                digit: digit(at: index),
                                placeholder: placeholderChar(at: index),
                                isActive: isFocused && code.count == index,
                                hasError: hasError,
                                hasWarning: hasWarning,
                                isEnabled: isEnabled,
                                isSecure: isSecure,
                                size: effectiveSize
                            )
                        }
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
                    .otpKeyboard(for: characterSet)
                    .opacity(0.001)
                    .frame(width: 1, height: 1)
                    .disabled(!isEnabled)
                    .onChange(of: code) { _, newValue in
                        let sanitized = Self.sanitize(newValue, digitCount: digitCount, characters: characterSet)
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
        // Message rows carry the HeroUI FieldError transition; key it here so
        // it plays (and snaps under `microAnimations(false)` / Reduce Motion /
        // `fieldDefaults(messagesAnimated: false)`).
        .animation(MicroMotion.animation(.fast, enabled: messagesAnimated, reduceMotion: reduceMotion), value: messages)
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

    /// The placeholder glyph for the cell at `index` — one character of the
    /// `placeholder(_:)` string per slot position ("" past its end).
    private func placeholderChar(at index: Int) -> String {
        guard let placeholderText else { return "" }
        let characters = Array(placeholderText)
        guard index < characters.count else { return "" }
        return String(characters[index])
    }
}

private extension View {
    /// Applies keyboard + one-time-code traits for the character set (iOS only):
    /// digits get the number pad; letters/alphanumeric get an ASCII keyboard
    /// with capitalization and autocorrection off (matching HeroUI, which keeps
    /// letters as typed).
    @ViewBuilder
    func otpKeyboard(for characters: OTPCharacterSet) -> some View {
        #if os(iOS)
        self.keyboardType(characters == .digits ? .numberPad : .asciiCapable)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.oneTimeCode)
        #else
        self
        #endif
    }
}

/// The dash between slot groups — HeroUI's `InputOTP.Separator` (a short
/// rounded bar in a muted tone). Purely decorative; the surrounding `HStack`'s
/// `sm` spacing provides the gap on both sides.
private struct OTPGroupSeparator: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Capsule()
            .fill(theme.text(.textTertiary))
            .frame(width: 8, height: 2)
            .accessibilityHidden(true)
    }
}

/// One digit cell — a mini-field. Its chrome (fill + border) is delegated to the
/// active ``FieldStyle`` per cell: the caret cell maps to `isFocused: true`, every
/// other cell to `false`, and the component's error/warning state fans out to all
/// cells. `size` defaults to `.medium` — the classic 56pt cell height is exactly
/// the `.medium` field height; the subtree `FieldDefaults.size` remaps it (OTP
/// has no `TextInputSize` modifier of its own).
private struct OTPDigitBox: View {
    @Environment(\.theme) private var theme
    /// The cell chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle

    let digit: String
    let placeholder: String
    let isActive: Bool
    let hasError: Bool
    let hasWarning: Bool
    let isEnabled: Bool
    let isSecure: Bool
    let size: TextInputSize

    @State private var caretOn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.microAnimations) private var micro

    /// Digit-entry motion plays only when the library switch is on *and*
    /// Reduce Motion is off — same gate the caret blink uses.
    private var motionOn: Bool { micro && !reduceMotion }

    var body: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(cellContent),
            isFocused: isActive,      // only the caret cell reads as focused
            isEnabled: isEnabled,
            hasError: hasError,       // validation fans out to every cell
            hasWarning: hasWarning,
            size: size                // classic 56pt cell == `.medium` field height
        ))
    }

    /// The cell's glyph layer (caret / digit / mask dot), sized — everything the
    /// ``FieldStyle`` receives as `configuration.content`.
    private var cellContent: some View {
        ZStack {
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
                } else if !placeholder.isEmpty {
                    // HeroUI SlotPlaceholder: shown only while the cell is
                    // empty and not the caret cell, in the muted text tone.
                    Text(placeholder)
                        .textStyle(.headingBase)
                        .foregroundStyle(theme.text(.textTertiary))
                }
            } else {
                Text(isSecure ? "●" : digit)
                    .textStyle(.headingBase)
                    .foregroundStyle(textColor)
                    // Entry pop (HeroUI SlotValue): scale+fade in; edits to an
                    // already-filled cell roll via the numeric transition.
                    .transition(motionOn ? .scale(scale: 0.8).combined(with: .opacity) : .identity)
                    .contentTransition(motionOn ? .numericText() : .identity)
            }
        }
        .animation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion), value: digit)
        // Fixed height: the box is a square cell in a fixed-width grid;
        // Dynamic Type is capped at the container via dynamicTypeClamp().
        .frame(height: size.height)
        .frame(maxWidth: .infinity)
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
        @State var grouped = "12"
        @State var alpha = "A1"
        @State var lastComplete = "—"
        var body: some View {
            VStack(spacing: 24) {
                OTPInput(code: $code, onComplete: { lastComplete = $0 }).resend(interval: 30, onResend: {})
                Text("Completed: \(lastComplete)").textStyle(.bodySm400)
                OTPInput(code: .constant("4321")).digitCount(4).secure()
                OTPInput(code: .constant("12")).digitCount(4).errorText("Invalid code")
                // Swapped chrome: every digit cell picks up the underlined style.
                OTPInput(code: .constant("98")).digitCount(4).fieldStyle(.underlined)
                // HeroUI Group/Separator anatomy: 3 + 3 with a dash between.
                OTPInput(code: $grouped).groups([3, 3])
                // Letters + digits: ASCII keyboard, `.oneTimeCode` kept.
                OTPInput(code: $alpha).characters(.alphanumeric)
                // Per-slot placeholder in the tertiary text tone.
                OTPInput(code: .constant("7")).digitCount(4).placeholder("0000")
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

    /// Which characters the field accepts (default `.digits`). Also switches
    /// the iOS keyboard: number pad for digits, ASCII keyboard otherwise —
    /// `.oneTimeCode` autofill stays on either way.
    func characters(_ set: OTPCharacterSet) -> Self { copy { $0.characterSet = set } }

    /// Splits the boxes into visual groups separated by a small dash, e.g.
    /// `.groups([3, 3])` for `123 - 456`. Sizes must be positive and sum to
    /// `digitCount`; invalid sizes are ignored (single group). The separator is
    /// decorative only — entry still flows through one field.
    func groups(_ sizes: [Int]) -> Self { copy { $0.groupSizes = sizes } }

    /// Per-slot placeholder: each empty, non-caret box shows the character at
    /// its position (e.g. `"------"` or `"000000"`) in the tertiary text tone.
    func placeholder(_ text: String) -> Self { copy { $0.placeholderText = text } }

    /// Control-height preset. An explicit size wins over the subtree
    /// `FieldDefaults.size` default.
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

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
