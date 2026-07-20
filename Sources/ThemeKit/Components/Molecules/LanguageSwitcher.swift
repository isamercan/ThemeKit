//
//  LanguageSwitcher.swift
//  ThemeKit
//
//  Molecule. A brand-neutral app-language picker (ThemeKitTravel plan §9.12 —
//  neutral placement, next to ``CurrencyPicker``/``SegmentedControl``). One
//  component, three archetypes:
//
//  - `.menu` (default) — a compact field-styled trigger opening a ``Dropdown``.
//  - `.list` — check-marked rows for settings screens.
//  - `.inline` — a ``SegmentedControl`` for 2–3 languages.
//
//  Controlled-only (ADR-F4): the caller owns `selection` (a BCP-47 code).
//  Names are locale-derived: endonyms ("Deutsch", "العربية") by default via
//  `Locale(identifier:).localizedString(forIdentifier:)`, exonyms in the
//  environment locale with `.nativeNames(false)`. Flags derive from the
//  language's likely region when not supplied. Token-bound, RTL-safe,
//  Dynamic-Type via `.textStyle(_:)`, `\.isReadOnly`-aware.
//

import SwiftUI

// MARK: - Model

/// One selectable app language, identified by its BCP-47 code ("en", "de",
/// "ar", "en-GB"…). `name` and `flag` are optional overrides — omitted, the
/// display name derives from `Locale` and the flag from the language's likely
/// region (en → 🇺🇸, de → 🇩🇪, en-GB → 🇬🇧).
public struct AppLanguage: Identifiable, Sendable, Hashable {
    public var id: String { code }
    /// BCP-47 language identifier — "en", "de", "ar", "en-GB".
    public let code: String
    /// Display-name override; `nil` derives a localized name via `Locale`.
    public var name: String?
    /// Flag-emoji override; `nil` derives one from the likely region.
    public var flag: String?

    public init(code: String, name: String? = nil, flag: String? = nil) {
        self.code = code
        self.name = name
        self.flag = flag
    }

    /// The language's own name for itself ("Deutsch", "العربية"). Override wins.
    var endonym: String {
        name ?? Locale(identifier: code).localizedString(forIdentifier: code) ?? code
    }

    /// The name in `locale` ("German", "Arabic"). Override wins.
    func exonym(in locale: Locale) -> String {
        name ?? locale.localizedString(forLanguageCode: code) ?? code
    }

    /// Explicit flag, else a regional-indicator emoji from the language's
    /// region subtag — maximized when the code carries none ("en" → en-Latn-US).
    var resolvedFlag: String? {
        if let flag { return flag }
        guard let region = Self.regionSubtag(of: code),
              region.count == 2 else { return nil }
        let base: UInt32 = 127_397   // regional-indicator 🇦 minus ASCII 'A'
        var out = ""
        for scalar in region.uppercased().unicodeScalars {
            if let v = UnicodeScalar(base + scalar.value) { out.unicodeScalars.append(v) }
        }
        return out.isEmpty ? nil : out
    }

    /// The region subtag driving the flag. `Locale.Language` (iOS 16+) resolves
    /// the likely region for bare codes ("en" → en-Latn-US → US); below 16 the
    /// named ``legacyRegionSubtag(of:)`` unit parses only an explicit subtag —
    /// iOS 15 has no likely-subtags API, so a bare "en" simply renders without
    /// a flag there (ADR-0007 §D2 rule 2).
    static func regionSubtag(of code: String) -> String? {
        if #available(iOS 16.0, *) {
            let language = Locale.Language(identifier: code)
            return (language.region ?? Locale.Language(identifier: language.maximalIdentifier).region)?.identifier
        } else {
            return legacyRegionSubtag(of: code)
        }
    }

    /// Named legacy unit (ADR-0007 §D2 rule 3, unit-tested directly): BCP-47
    /// subtag parse for the pre-16 path — "en-GB"/"en_GB" → "GB",
    /// "zh-Hant-TW" → "TW", bare "en" → nil (no flag).
    static func legacyRegionSubtag(of code: String) -> String? {
        for tag in code.split(whereSeparator: { $0 == "-" || $0 == "_" }).dropFirst() {
            if tag.count == 2, tag.allSatisfy(\.isLetter) { return tag.uppercased() }
            if tag.count == 3, tag.allSatisfy(\.isNumber) { return String(tag) }   // UN M.49 code
        }
        return nil
    }
}

// MARK: - Variant

/// How the switcher presents its options.
public enum LanguageSwitcherVariant: Sendable {
    /// A compact field-styled trigger opening a ``Dropdown`` (default).
    case menu
    /// Check-marked rows for settings screens.
    case list
    /// A ``SegmentedControl`` — best for 2–3 languages.
    case inline
}

// MARK: - Component

/// A token-bound app-language picker. Controlled-only (ADR-F4).
///
/// ```swift
/// LanguageSwitcher([.init(code: "en"), .init(code: "de"), .init(code: "ar")],
///                  selection: $languageCode)
///     .variant(.list)
///     .nativeNames()
/// ```
public struct LanguageSwitcher: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled     // R3 — set natively by `.disabled(_:)`
    /// Read-only subtree axis (`.readOnly(_:)`) — normal chrome, selection locked.
    @Environment(\.isReadOnly) private var isReadOnly
    /// Exonyms render in this locale (`.environment(\.locale, _:)`-injectable).
    @Environment(\.locale) private var locale
    @Environment(\.componentDefaults) private var componentDefaults

    private let languages: [AppLanguage]
    @Binding private var selection: String

    // Appearance — mutated only through the modifiers below (R2).
    private var variantKind: LanguageSwitcherVariant = .menu
    private var showsFlags = true
    private var usesNativeNames = true
    /// Explicit `.accent(_:)`; `nil` defers to the subtree `componentDefaults`
    /// accent, then the theme's hero foreground.
    private var accentColor: SemanticColor?

    public init(_ languages: [AppLanguage], selection: Binding<String>) {   // R1
        self.languages = languages
        self._selection = selection
    }

    // MARK: Resolution

    private var resolvedAccent: SemanticColor? { accentColor ?? componentDefaults.accent }
    private var checkColor: Color { resolvedAccent.map { theme.resolve($0).accent } ?? theme.foreground(.fgHero) }
    private var selected: AppLanguage? { languages.first { $0.code == selection } }

    /// Primary display name per the `nativeNames` axis.
    private func displayName(_ language: AppLanguage) -> String {
        usesNativeNames ? language.endonym : language.exonym(in: locale)
    }

    /// "Deutsch, German" — VoiceOver reads endonym and exonym when they differ.
    private func accessibilityText(_ language: AppLanguage) -> String {
        let endonym = language.endonym
        let exonym = language.exonym(in: locale)
        return endonym == exonym ? endonym : "\(endonym), \(exonym)"
    }

    private func select(_ language: AppLanguage) {
        guard !isReadOnly else { return }   // E1 — read-only keeps chrome, locks value
        selection = language.code
    }

    public var body: some View {
        Group {
            switch variantKind {
            case .menu: menuVariant
            case .list: listVariant
            case .inline: inlineVariant
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(String(themeKit: "Language")))
    }

    // MARK: .menu — Dropdown behind a field-styled trigger

    private var menuVariant: some View {
        Dropdown(items: languages.map { language in
            DropdownItem(
                menuTitle(language),
                subtitle: usesNativeNames && language.endonym != language.exonym(in: locale)
                    ? language.exonym(in: locale) : nil,
                isSelected: language.code == selection
            ) { select(language) }
        }) {
            menuTrigger
        }
        .indicator(.checkmark)
        .accent(resolvedAccent ?? .neutral)
        .allowsHitTesting(!isReadOnly)
        .accessibilityValue(selected.map { Text(accessibilityText($0)) } ?? Text(""))
    }

    private func menuTitle(_ language: AppLanguage) -> String {
        guard showsFlags, let flag = language.resolvedFlag else { return displayName(language) }
        return "\(flag) \(displayName(language))"
    }

    /// The closed-state trigger — flag, current name, chevron — in field chrome.
    private var menuTrigger: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if showsFlags, let flag = selected?.resolvedFlag {
                Text(flag).textStyle(.bodyBase400)
            }
            Text(selected.map(displayName) ?? String(themeKit: "Select language"))
                .textStyle(.labelBase600)
                .foregroundStyle(selected == nil ? theme.text(.textTertiary) : theme.text(.textPrimary))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .textStyle(.labelSm600)
                .foregroundStyle(theme.text(.textTertiary))
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(
            theme.background(.bgWhite),
            in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
                .stroke(theme.border(.borderPrimary), lineWidth: 1)
        )
        .opacity(isEnabled ? 1 : 0.5)
    }

    // MARK: .list — check-marked rows

    private var listVariant: some View {
        VStack(spacing: 0) {
            ForEach(Array(languages.enumerated()), id: \.element.id) { index, language in
                if index > 0 { Divider().overlay(theme.border(.borderPrimary)) }
                listRow(language)
            }
        }
    }

    private func listRow(_ language: AppLanguage) -> some View {
        let isSelected = language.code == selection
        return Button { select(language) } label: {
            HStack(spacing: Theme.SpacingKey.md.value) {
                if showsFlags, let flag = language.resolvedFlag {
                    Text(flag).textStyle(.bodyLg400)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(language))
                        .textStyle(.labelBase600)
                        .foregroundStyle(theme.text(.textPrimary))
                    if usesNativeNames, language.endonym != language.exonym(in: locale) {
                        Text(language.exonym(in: locale))
                            .textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textTertiary))
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .textStyle(.labelMd600)
                        .foregroundStyle(checkColor)
                }
            }
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isReadOnly)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(accessibilityText(language))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: .inline — SegmentedControl

    private var inlineVariant: some View {
        SegmentedControl(
            languages.map { language in
                SegmentItem(menuTitle(language), tooltip: accessibilityText(language))
            },
            selection: Binding(
                get: { languages.firstIndex { $0.code == selection } ?? 0 },
                set: { index in
                    guard !isReadOnly, languages.indices.contains(index) else { return }
                    selection = languages[index].code
                }
            )
        )
        .accent(resolvedAccent)
        .allowsHitTesting(!isReadOnly)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension LanguageSwitcher {
    /// Presentation archetype — `.menu` (default), `.list`, or `.inline`.
    func variant(_ v: LanguageSwitcherVariant) -> Self { copy { $0.variantKind = v } }
    /// Shows a flag emoji before each name (default true). Flags derive from
    /// the language's likely region when the model carries none.
    func showsFlags(_ on: Bool = true) -> Self { copy { $0.showsFlags = on } }
    /// Renders each language endonymically ("Deutsch", "العربية") — default
    /// true. Off = exonyms in the environment locale ("German", "Arabic").
    func nativeNames(_ on: Bool = true) -> Self { copy { $0.usesNativeNames = on } }
    /// Selection tint: explicit → subtree `componentDefaults` accent → the
    /// theme's hero foreground. Pass `nil` to restore the cascade.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentColor = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("Variants") {
    struct Demo: View {
        @State private var code = "en"
        private let languages: [AppLanguage] = [
            AppLanguage(code: "en"), AppLanguage(code: "de"),
            AppLanguage(code: "fr"), AppLanguage(code: "ar"),
        ]
        var body: some View {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                LanguageSwitcher(languages, selection: $code)                       // .menu
                LanguageSwitcher(languages, selection: $code).variant(.list)
                LanguageSwitcher(Array(languages.prefix(3)), selection: $code).variant(.inline)
                LanguageSwitcher(languages, selection: $code).variant(.list)
                    .showsFlags(false).nativeNames(false).accent(.success)
                LanguageSwitcher(languages, selection: $code).variant(.list).readOnly()
            }
            .padding()
        }
    }
    return Demo()
}

#Preview("Dark") {
    struct Demo: View {
        @State private var code = "de"
        private let languages: [AppLanguage] = [
            AppLanguage(code: "en"), AppLanguage(code: "de"), AppLanguage(code: "ar"),
        ]
        var body: some View {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                LanguageSwitcher(languages, selection: $code)
                LanguageSwitcher(languages, selection: $code).variant(.list)
            }
            .padding()
        }
    }
    return Demo().preferredColorScheme(.dark)
}

#Preview("RTL") {
    struct Demo: View {
        @State private var code = "ar"
        private let languages: [AppLanguage] = [
            AppLanguage(code: "ar"), AppLanguage(code: "en"), AppLanguage(code: "tr"),
        ]
        var body: some View {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                LanguageSwitcher(languages, selection: $code).variant(.list)
                LanguageSwitcher(languages, selection: $code).variant(.inline)
            }
            .padding()
        }
    }
    return Demo().environment(\.layoutDirection, .rightToLeft)
}
