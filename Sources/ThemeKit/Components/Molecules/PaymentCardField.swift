//
//  PaymentCardField.swift
//  ThemeKit
//
//  Molecule. A credit-card entry group — a formatted card-number field with live
//  brand detection, an expiry (MM/YY) and a CVV field, plus an optional cardholder
//  field. Token-bound. Bindings are owned by the caller.
//
//  ```swift
//  PaymentCardField(number: $number, expiry: $expiry, cvv: $cvv).holder($name)
//  ```
//

import SwiftUI

/// Card network detected from the number prefix.
public enum CardBrand: String, Sendable, CaseIterable {
    case visa, mastercard, amex, troy, unknown

    public var label: String {
        switch self { case .visa: "Visa"; case .mastercard: "Mastercard"; case .amex: "Amex"; case .troy: "Troy"; case .unknown: "" }
    }
    public var icon: String { "creditcard.fill" }

    public static func detect(_ number: String) -> CardBrand {
        let d = number.filter(\.isNumber)
        guard let first = d.first else { return .unknown }
        if d.hasPrefix("9792") { return .troy }
        switch first {
        case "4": return .visa
        case "5": return .mastercard
        case "3": return .amex
        default: return .unknown
        }
    }
}

public struct PaymentCardField: View {
    @Environment(\.theme) private var theme
    /// The per-row field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    /// There is no outer card shell here — each row (number / expiry / CVV /
    /// holder) is its own field box, so the whole box chroma belongs to
    /// `FieldStyle`, not `CardStyle`.
    @Environment(\.fieldStyle) private var fieldStyle
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`

    /// Which of the four field rows currently holds keyboard focus.
    private enum FieldRole: Hashable { case number, expiry, cvv, holder }
    @FocusState private var focused: FieldRole?

    @Binding private var number: String
    @Binding private var expiry: String
    @Binding private var cvv: String
    // Config — mutated only through the modifiers below (R2).
    private var holder: Binding<String>?
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var numberPlaceholder = "Card number"
    private var holderPlaceholder = "Cardholder name"

    public init(number: Binding<String>, expiry: Binding<String>, cvv: Binding<String>) {   // R1
        self._number = number
        self._expiry = expiry
        self._cvv = cvv
    }

    private var brand: CardBrand { CardBrand.detect(number) }
    private var accentBase: Color { (accent ?? .primary).base }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous) }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            numberField
            HStack(spacing: Theme.SpacingKey.sm.value) {
                fieldBox(.expiry) {
                    field($expiry, "MM/YY", role: .expiry, keyboard: .numberPad) { formatExpiry($0) }
                }
                fieldBox(.cvv) {
                    field($cvv, "CVV", role: .cvv, keyboard: .numberPad, secure: true) { String($0.filter(\.isNumber).prefix(4)) }
                }
            }
            if let holder {
                fieldBox(.holder) { field(holder, holderPlaceholder, role: .holder) { $0 } }
            }
        }
    }

    private var numberField: some View {
        fieldBox(.number) {
            HStack(spacing: 8) {
                field($number, numberPlaceholder, role: .number, keyboard: .numberPad) { formatNumber($0) }
                if brand != .unknown {
                    HStack(spacing: 4) {
                        Image(systemName: brand.icon).font(.system(size: 15)).foregroundStyle(accentBase)
                        Text(brand.label).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    /// One field row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Mapping: `isFocused` is true for the row whose editor holds focus;
    /// `hasError`/`hasWarning` are always `false` (this component has no
    /// validation axis); `size` is `.medium` — the rows have no `TextInputSize`
    /// axis (they keep their fixed 52pt min-height in the content). A custom
    /// `surface(_:)` key (anything other than the default `.bgBase`) is painted
    /// inside the content so the modifier keeps working; with the default key the
    /// fill is left entirely to the style.
    private func fieldBox<Content: View>(_ role: FieldRole, @ViewBuilder _ content: () -> Content) -> some View {
        let row = content()
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
        return fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: surfaceKey == .bgWhite
                ? AnyView(row)
                : AnyView(row.background(theme.background(surfaceKey), in: shape)),
            isFocused: focused == role,
            isEnabled: isEnabled,
            hasError: false,
            hasWarning: false,
            size: .medium
        ))
    }

    @ViewBuilder private func field(_ binding: Binding<String>, _ placeholder: String, role: FieldRole, keyboard: KeyboardKind = .default, secure: Bool = false, format: @escaping (String) -> String) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: binding)
            } else {
                TextField(placeholder, text: binding)
            }
        }
        .focused($focused, equals: role)
        .textStyle(.bodyBase400)
        .foregroundStyle(theme.text(.textPrimary))
        .applyKeyboard(keyboard)
        .onChange(of: binding.wrappedValue) { _, new in
            let f = format(new)
            if f != new { binding.wrappedValue = f }
        }
    }

    private func formatNumber(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(19))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && i % 4 == 0 { out.append(" ") }
            out.append(ch)
        }
        return out
    }
    private func formatExpiry(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(4))
        guard digits.count > 2 else { return digits }
        let idx = digits.index(digits.startIndex, offsetBy: 2)
        return digits[..<idx] + "/" + digits[idx...]
    }
}

// MARK: Cross-platform keyboard helper

/// Keyboard hint that no-ops on macOS (where `.keyboardType` is unavailable).
public enum KeyboardKind: Sendable { case `default`, numberPad }

private extension View {
    @ViewBuilder func applyKeyboard(_ kind: KeyboardKind) -> some View {
        #if os(iOS)
        switch kind {
        case .default: self
        case .numberPad: self.keyboardType(.numberPad)
        }
        #else
        self
        #endif
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PaymentCardField {
    /// Adds a cardholder-name field bound to `binding`.
    func holder(_ binding: Binding<String>) -> Self { copy { $0.holder = binding } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Custom fill for the field rows, painted *inside* the ``FieldStyle`` chrome.
    /// With the default `.bgBase` the fill is left entirely to the style.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    func placeholders(number: String? = nil, holder: String? = nil) -> Self {
        copy { if let number { $0.numberPlaceholder = number }; if let holder { $0.holderPlaceholder = holder } }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var num = ""
        @State private var exp = ""
        @State private var cvv = ""
        @State private var name = ""
        var body: some View {
            VStack(spacing: 24) {
                PaymentCardField(number: $num, expiry: $exp, cvv: $cvv).holder($name)
                // Swapped chrome: every field row picks up the underlined style.
                PaymentCardField(number: $num, expiry: $exp, cvv: $cvv)
                    .fieldStyle(.underlined)
            }
            .padding()
        }
    }
    return Demo()
}
