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
                fieldBox {
                    field($expiry, "MM/YY", keyboard: .numberPad) { formatExpiry($0) }
                }
                fieldBox {
                    field($cvv, "CVV", keyboard: .numberPad, secure: true) { String($0.filter(\.isNumber).prefix(4)) }
                }
            }
            if let holder {
                fieldBox { field(holder, holderPlaceholder) { $0 } }
            }
        }
    }

    private var numberField: some View {
        fieldBox {
            HStack(spacing: 8) {
                field($number, numberPlaceholder, keyboard: .numberPad) { formatNumber($0) }
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

    private func fieldBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background(surfaceKey), in: shape)
            .overlay(shape.stroke(theme.border(.borderPrimary), lineWidth: 1))
    }

    @ViewBuilder private func field(_ binding: Binding<String>, _ placeholder: String, keyboard: KeyboardKind = .default, secure: Bool = false, format: @escaping (String) -> String) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: binding)
            } else {
                TextField(placeholder, text: binding)
            }
        }
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
            PaymentCardField(number: $num, expiry: $exp, cvv: $cvv).holder($name).padding()
        }
    }
    return Demo()
}
