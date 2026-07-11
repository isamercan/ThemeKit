//
//  PhoneField.swift
//  ThemeKit
//  Created by İsa Mercan on 11.07.2026.
//
//  International phone input (F1.1): a leading country dial-code selector +
//  national-number field, presented as *one* field to the FieldStyle system.
//  The entire field body is a `TextInput` — chrome, size, `infoMessages`,
//  `externalFocus`, validation and read-only behavior are all inherited — with
//  the dial-code trigger composed into its `.leading { }` view slot.
//
//  Dial-code state is dual-mode via `@ControllableState` (ADR-4): uncontrolled
//  by default (seeded from the environment locale's region), controlled when
//  the caller passes `dialCode: Binding<DialCode>`.
//

import SwiftUI

// MARK: - DialCode

/// A country calling code: ISO 3166-1 alpha-2 region, `+`-prefixed dial code,
/// and a display name + emoji flag (both derivable from the region).
public struct DialCode: Sendable, Equatable, Hashable, Identifiable, Codable {
    /// ISO 3166-1 alpha-2 region code, uppercased (e.g. `"TR"`).
    public let regionCode: String
    /// `+`-prefixed international calling code (e.g. `"+90"`).
    public let code: String
    /// Display name (defaults to the English region name from `Locale`).
    public let name: String
    /// Emoji flag (defaults to the regional-indicator flag for `regionCode`).
    public let flag: String

    public var id: String { regionCode }

    public init(regionCode: String, code: String, name: String? = nil, flag: String? = nil) {
        let region = regionCode.uppercased()
        self.regionCode = region
        self.code = code
        self.name = name
            ?? Locale(identifier: "en_US").localizedString(forRegionCode: region)
            ?? region
        self.flag = flag ?? Self.emojiFlag(for: region)
    }

    /// Regional-indicator emoji flag for an alpha-2 region code ("TR" → "🇹🇷").
    static func emojiFlag(for region: String) -> String {
        var result = ""
        for scalar in region.uppercased().unicodeScalars {
            // Regional Indicator Symbol Letter A (U+1F1E6) is offset from "A" (65).
            guard scalar.value >= 65, scalar.value <= 90,
                  let indicator = Unicode.Scalar(0x1F1E6 + scalar.value - 65) else { return "" }
            result.unicodeScalars.append(indicator)
        }
        return result
    }

    /// The default dial code for `locale` within `list`: the entry matching the
    /// locale's region, else the first entry.
    static func `default`(for locale: Locale, in list: [DialCode]) -> DialCode? {
        let region = locale.region?.identifier.uppercased()
        return list.first { $0.regionCode == region } ?? list.first
    }
}

public extension DialCode {
    /// A generic international starter set (English display names), sorted by name.
    static let common: [DialCode] = [
        DialCode(regionCode: "AU", code: "+61"),
        DialCode(regionCode: "AT", code: "+43"),
        DialCode(regionCode: "BE", code: "+32"),
        DialCode(regionCode: "BR", code: "+55"),
        DialCode(regionCode: "CA", code: "+1"),
        DialCode(regionCode: "CN", code: "+86"),
        DialCode(regionCode: "DK", code: "+45"),
        DialCode(regionCode: "EG", code: "+20"),
        DialCode(regionCode: "FI", code: "+358"),
        DialCode(regionCode: "FR", code: "+33"),
        DialCode(regionCode: "DE", code: "+49"),
        DialCode(regionCode: "GR", code: "+30"),
        DialCode(regionCode: "IN", code: "+91"),
        DialCode(regionCode: "IE", code: "+353"),
        DialCode(regionCode: "IT", code: "+39"),
        DialCode(regionCode: "JP", code: "+81"),
        DialCode(regionCode: "MX", code: "+52"),
        DialCode(regionCode: "NL", code: "+31"),
        DialCode(regionCode: "NZ", code: "+64"),
        DialCode(regionCode: "NO", code: "+47"),
        DialCode(regionCode: "PL", code: "+48"),
        DialCode(regionCode: "PT", code: "+351"),
        DialCode(regionCode: "SA", code: "+966"),
        DialCode(regionCode: "KR", code: "+82"),
        DialCode(regionCode: "ES", code: "+34"),
        DialCode(regionCode: "SE", code: "+46"),
        DialCode(regionCode: "CH", code: "+41"),
        DialCode(regionCode: "TR", code: "+90"),
        DialCode(regionCode: "AE", code: "+971"),
        DialCode(regionCode: "GB", code: "+44"),
        DialCode(regionCode: "US", code: "+1"),
    ]
}

// MARK: - PhoneField

/// Molecule. International phone input: a leading dial-code selector + a
/// national-number `TextInput`, rendered as one field. Per the modifier-based
/// architecture (R1) the inits take only the label and bindings; every other
/// axis is a chainable, order-free modifier. Field chrome, size, messages,
/// focus and read-only behavior are the `TextInput` family's — set them the
/// usual way (`.fieldStyle(_:)`, `.fieldDefaults(…)`, `.readOnly()`, …).
///
///     // Dial code inferred from the locale, self-managed:
///     PhoneField("Phone", number: $phone)
///
///     // Controlled — the caller owns region/prefix state:
///     PhoneField("Contact phone", number: $draft.phone, dialCode: $draft.dialCode)
///         .dialCodes(DialCode.common)
///         .infoMessages(form.messages(for: .phone))
///         .externalFocus(form.focusBinding(.phone))
public struct PhoneField: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isReadOnly) private var isReadOnly   // E1 — set by `.readOnly(_:)`

    private let label: String
    @Binding private var number: String
    /// Dual-mode dial-code state (ADR-4). Uncontrolled stores `nil` until the
    /// user picks, so the *effective* value keeps following the environment
    /// locale's region; controlled routes through the caller's binding.
    @ControllableState private var selectedDialCode: DialCode?

    // Config — mutated only through the modifiers below (R2).
    private var dialCodeList: [DialCode] = DialCode.common
    private var placeholderText: String? = nil
    /// Set only by `.searchablePicker(_:)`; `nil` → searchable when the list
    /// has more than 8 entries (§9.1 default).
    private var explicitSearchable: Bool? = nil
    private var formatsNumber = false
    private var infoMessages: [InfoMessage] = []
    private var externalFocus: Binding<Bool>? = nil
    private var isRequired = false
    private var accessibilityID: String? = nil

    @State private var showsPicker = false
    @State private var query = ""

    /// R1 — label + national-number binding. Dial code self-manages, seeded
    /// from the environment locale's region (uncontrolled).
    public init(_ label: String, number: Binding<String>) {
        self.label = label
        self._number = number
        self._selectedDialCode = ControllableState(wrappedValue: nil)
    }

    /// Controlled dial code — the caller owns region/prefix state.
    public init(_ label: String, number: Binding<String>, dialCode: Binding<DialCode>) {
        self.label = label
        self._number = number
        self._selectedDialCode = ControllableState(
            wrappedValue: nil,
            external: Binding<DialCode?>(
                get: { dialCode.wrappedValue },
                set: { if let newValue = $0 { dialCode.wrappedValue = newValue } }
            )
        )
    }

    /// Picked value → locale-matched entry → first entry → a neutral fallback
    /// (only reachable with an empty `dialCodes(_:)` list).
    private var effectiveDialCode: DialCode {
        selectedDialCode
            ?? DialCode.default(for: locale, in: dialCodeList)
            ?? DialCode(regionCode: "US", code: "+1")
    }

    /// Explicit `.searchablePicker(_:)` → list-size heuristic (§9.1).
    private var isSearchable: Bool { explicitSearchable ?? (dialCodeList.count > 8) }

    private var filteredCodes: [DialCode] {
        guard !query.isEmpty else { return dialCodeList }
        return dialCodeList.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.code.contains(query)
                || $0.regionCode.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        TextInput(label, text: $number)
            .placeholder(placeholderText ?? String(themeKit: "Phone number"))
            .keyboard(.numberPad, contentType: .telephoneNumber)
            .formatter(formatsNumber ? .phoneGrouped() : nil)
            .infoMessages(infoMessages)
            .externalFocus(externalFocus)
            .required(isRequired)
            .a11yID(accessibilityID)
            .leading { dialCodeTrigger }
    }

    // MARK: Dial-code trigger

    /// Plain `Menu` for short lists; a searchable sheet for long ones (§9.1).
    /// Lives in `TextInput`'s `.leading { }` slot — child controls win over the
    /// field's tap-to-focus gesture (same as the shipped clear/reveal buttons).
    @ViewBuilder
    private var dialCodeTrigger: some View {
        if isSearchable {
            Button {
                query = ""
                showsPicker = true
            } label: {
                triggerLabel
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .allowsHitTesting(!isReadOnly)   // E1 — value stays, picker blocked
            .sheet(isPresented: $showsPicker) { pickerSheet }
        } else {
            Menu {
                ForEach(dialCodeList) { option in
                    Button {
                        selectedDialCode = option
                    } label: {
                        if option == effectiveDialCode {
                            Label("\(option.flag) \(option.name) (\(option.code))", systemImage: "checkmark")
                        } else {
                            Text("\(option.flag) \(option.name) (\(option.code))")
                        }
                    }
                }
            } label: {
                triggerLabel
            }
            .disabled(!isEnabled)
            .allowsHitTesting(!isReadOnly)   // E1 — value stays, menu blocked
        }
    }

    private var triggerLabel: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(verbatim: effectiveDialCode.flag)
                .textStyle(.bodyBase400)
            Text(verbatim: effectiveDialCode.code)
                .textStyle(.bodyBase400)
                .foregroundStyle(isEnabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
                .monospacedDigit()
                // "+90" must not bidi-flip to "90+" under RTL (§10 RTL notes);
                // the trigger's *position* still mirrors with the leading slot.
                .environment(\.layoutDirection, .leftToRight)
            Icon(systemName: "chevron.down").size(.xs).color(theme.text(.textTertiary))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(themeKit: "Country code") + ", " + effectiveDialCode.code)
        .a11y(A11yElement.Select.trigger, in: accessibilityID)
    }

    // MARK: Searchable picker sheet

    private var pickerSheet: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            TextInput(String(themeKit: "Search"), text: $query)
                .icon(leading: "magnifyingglass")
                .clearable()
                .autocorrectionDisabled()
                .a11y(A11yElement.Select.search, in: accessibilityID)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCodes) { option in
                        pickerRow(option)
                    }
                }
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .background(theme.background(.bgBase))
        .phoneFieldSheetSizing()
    }

    private func pickerRow(_ option: DialCode) -> some View {
        Button {
            selectedDialCode = option
            showsPicker = false
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Text(verbatim: option.flag)
                    .textStyle(.bodyBase400)
                Text(option.name)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textPrimary))
                Spacer(minLength: Theme.SpacingKey.sm.value)
                Text(verbatim: option.code)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textSecondary))
                    .monospacedDigit()
                    .environment(\.layoutDirection, .leftToRight)   // keep "+44" LTR
                if option == effectiveDialCode {
                    Icon(systemName: "checkmark").size(.sm).color(theme.foreground(.fgHero))
                }
            }
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.name + ", " + option.code)
        .a11y(A11yElement.Select.option, in: accessibilityID)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PhoneField {
    /// The selectable dial codes (default: `DialCode.common`). Order preserved.
    func dialCodes(_ list: [DialCode]) -> Self { copy { $0.dialCodeList = list } }

    /// Placeholder for the national-number portion (default localized "Phone number").
    func placeholder(_ text: String) -> Self { copy { $0.placeholderText = text } }

    /// Searchable picker list (default: `true` when the list has more than 8
    /// entries). Searchable presents a sheet with a filter field; otherwise the
    /// trigger opens a plain menu.
    func searchablePicker(_ on: Bool = true) -> Self { copy { $0.explicitSearchable = on } }

    /// Groups digits as you type using the `TextInputFormatter` machinery.
    func formatsNumber(_ on: Bool = true) -> Self { copy { $0.formatsNumber = on } }

    /// Validation / info messages rendered under the field (drives the border
    /// state) — forwarded to the underlying `TextInput`.
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Drive focus from outside (e.g. `FormValidator.focusBinding`) — forwarded
    /// to the underlying `TextInput`.
    func externalFocus(_ binding: Binding<Bool>?) -> Self { copy { $0.externalFocus = binding } }

    /// Marks the field as required: error-token asterisk after the label +
    /// ", required" in the accessibility label — forwarded to the underlying
    /// `TextInput`.
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Sets the accessibility-identifier namespace (sub-elements get
    /// `"<id>.<element>"`) — forwarded to the underlying `TextInput`; the
    /// dial-code trigger gets `"<id>.trigger"`, picker rows `"<id>.option"`.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Formatter

public extension TextInputFormatter {
    /// Generic national-number grouping: digits in blocks of 3 (e.g.
    /// "532 123 456 7"), capped at `maxDigits` (ITU E.164 national numbers).
    static func phoneGrouped(maxDigits: Int = 12) -> TextInputFormatter {
        TextInputFormatter { raw in
            let digits = String(raw.filter(\.isNumber).prefix(maxDigits))
            return stride(from: 0, to: digits.count, by: 3).map {
                let start = digits.index(digits.startIndex, offsetBy: $0)
                let end = digits.index(start, offsetBy: min(3, digits.count - $0))
                return String(digits[start..<end])
            }.joined(separator: " ")
        }
    }
}

// MARK: - Sheet sizing (iOS detents; macOS sheets size to content)

private extension View {
    @ViewBuilder
    func phoneFieldSheetSizing() -> some View {
        #if os(iOS)
        self.presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
        self
        #endif
    }
}

// MARK: - Previews

#Preview {
    struct Demo: View {
        @State var phone = ""
        @State var contact = "5321234567"
        @State var dial = DialCode(regionCode: "GB", code: "+44")
        var body: some View {
            VStack(spacing: 16) {
                // Uncontrolled — dial code seeded from the environment locale.
                PhoneField("Phone", number: $phone)
                // Controlled + grouped digits.
                PhoneField("Contact phone", number: $contact, dialCode: $dial)
                    .formatsNumber()
                // Required indicator.
                PhoneField("Phone", number: .constant(""))
                    .required()
                // Error message via the shared InfoMessage model.
                PhoneField("Phone", number: .constant("123"))
                    .infoMessages([InfoMessage("Enter a valid phone number.", kind: .error)])
                // Short list (≤ 8) → plain Menu trigger; explicit placeholder.
                PhoneField("Phone (menu picker)", number: $phone)
                    .dialCodes(Array(DialCode.common.prefix(5)))
                    .placeholder("Mobile number")
                // Locale seeding — a German locale resolves "+49".
                PhoneField("Phone (de_DE locale)", number: .constant(""))
                    .environment(\.locale, Locale(identifier: "de_DE"))
                // Read-only (E1): normal chrome + value, editing/picker blocked.
                PhoneField("Phone (submitted)", number: .constant("532 123 45 67"))
                    .readOnly()
            }
            .padding()
        }
    }
    return Demo()
}

#Preview("RTL") {
    struct Demo: View {
        @State var phone = "5321234567"
        @State var dial = DialCode(regionCode: "TR", code: "+90")
        var body: some View {
            VStack(spacing: 16) {
                // Trigger mirrors to the leading edge; "+90" itself stays LTR.
                PhoneField("Phone", number: $phone, dialCode: $dial)
                    .formatsNumber()
                PhoneField("Phone", number: .constant(""))
                    .required()
            }
            .padding()
        }
    }
    return Demo().environment(\.layoutDirection, .rightToLeft)
}

#Preview("Dark / themed") {
    struct Demo: View {
        @State var phone = "5321234567"
        @State var dial = DialCode(regionCode: "TR", code: "+90")
        var body: some View {
            VStack(spacing: 16) {
                PhoneField("Phone", number: $phone, dialCode: $dial)
                    .formatsNumber()
                PhoneField("Phone", number: .constant(""))
                    .infoMessages([InfoMessage("Enter a valid phone number.", kind: .error)])
            }
            .padding()
        }
    }
    let dark = Theme()
    dark.loadTheme(named: Theme.defaultThemeName, dark: true)
    return Demo()
        .background(dark.background(.bgBase))
        .theme(dark)
}
