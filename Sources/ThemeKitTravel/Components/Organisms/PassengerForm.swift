//
//  PassengerForm.swift
//  ThemeKitTravel
//
//  Organism (§9.2, P0). The editable traveler-details form — name / gender /
//  date of birth / nationality / travel document — bound to a `PassengerDraft`.
//  Distinct from `PassengerRow` (a display row for review screens).
//
//  Composes neutral ThemeKit fields (`Fieldset`, `TextInput`, `SelectBox`,
//  `DateField`); all of them inherit `FieldDefaults` / `FieldStyle` from the
//  environment, so the form re-skins with the subtree's field chrome and needs
//  no style protocol of its own (structure, not skinnable chrome).
//
//  Controlled-only (ADR-F4): a traveler form the app can't read is useless.
//  Multi-passenger checkout is the app's `ForEach` of `PassengerForm`s — the
//  component stays single-traveler.
//
//  Validation (ADR-F6, §1.4 rev 4): `.validator(_:)` wires every rendered
//  field into one `FormValidator<PassengerFormField>`. Submission stays
//  app-side against the canonical serialization:
//
//      if form.validateAll(traveler.formValues) == nil { proceed(traveler) }
//
//  Wiring nuance (documented, fine for Phase 1): the TextInput-backed fields
//  (names, document number) use `.field(_:in:)` — their display string IS the
//  canonical string, so messages, focus-first-invalid and live re-validation
//  are exact. The SelectBox/DateField-backed fields display *localized* text
//  while the canonical value is ISO-8601 / `rawValue`, so the form re-validates
//  those from `draft.formValues` on change instead (same "only after the form
//  has validated the field" gate as `.field`). Their focus analogs are
//  best-effort: DateField opens its picker, SelectBox renders its focus ring.
//

import SwiftUI
import ThemeKit

// MARK: - PassengerFormField

/// The form's field keys — `FormValidator` keys, `formValues` keys, and the
/// `fields(_:)` render list all speak this vocabulary.
public enum PassengerFormField: Hashable, Sendable, CaseIterable {
    case givenName, familyName, gender, dateOfBirth, nationality, documentNumber, documentExpiry
}

// MARK: - PassengerForm

/// The editable traveler form for booking flows. Controlled-only: bind a
/// `PassengerDraft` and read it back whole.
///
///     @State private var traveler = PassengerDraft()
///     @State private var form = FormValidator<PassengerFormField>([
///         .givenName: [.required()], .familyName: [.required()],
///         .documentNumber: [.required(), .documentNumber],
///         .documentExpiry: [.expiryInFuture(after: tripDate)],
///     ])
///
///     PassengerForm("Passenger 1 · Adult", draft: $traveler)
///         .documentRequired()
///         .validator(form)
///
///     PrimaryButton("Continue") {
///         if form.validateAll(traveler.formValues) == nil { proceed(traveler) }
///     }
public struct PassengerForm: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale

    private let title: String
    @Binding private var draft: PassengerDraft

    // Appearance/config — mutated only through the modifiers below (R2).
    private var fieldList: [PassengerFormField] = Array(PassengerFormField.allCases)
    private var explicitNationalities: [String]?
    private var isDocumentRequired = false
    private var explicitBirthRange: ClosedRange<Date>?
    private var form: FormValidator<PassengerFormField>?
    private var accent: SemanticColor?
    private var customHeader: AnyView?
    private var customFooter: AnyView?

    /// R1 — title + controlled draft. Controlled-only (ADR-F4).
    public init(_ title: String, draft: Binding<PassengerDraft>) {
        self.title = title
        self._draft = draft
    }

    // MARK: Derived state

    private static let personalSection: [PassengerFormField] = [.givenName, .familyName, .gender, .dateOfBirth, .nationality]
    private static let documentSection: [PassengerFormField] = [.documentNumber, .documentExpiry]

    /// The render list partitioned into the two fieldsets, preserving the
    /// caller's `fields(_:)` order within each.
    private var personalFields: [PassengerFormField] { fieldList.filter(Self.personalSection.contains) }
    private var documentFields: [PassengerFormField] { fieldList.filter(Self.documentSection.contains) }

    /// Default DOB window: 120 years back … today. Clamped either way.
    private var birthRange: ClosedRange<Date> {
        if let explicitBirthRange { return explicitBirthRange }
        let floor = Calendar.current.date(byAdding: .year, value: -120, to: .now) ?? .distantPast
        return floor...Date.now
    }

    /// Expiry picker window: today … +50 years (an expiry is future by nature;
    /// the *policy* check — valid past the trip date — is the validator's job).
    private var expiryRange: ClosedRange<Date> {
        let ceiling = Calendar.current.date(byAdding: .year, value: 50, to: .now) ?? .distantFuture
        return Date.now...ceiling
    }

    /// ISO 3166-1 region codes for the nationality selector, sorted by their
    /// localized display name in the environment locale.
    private var nationalityCodes: [String] {
        let codes = explicitNationalities
            ?? Locale.Region.isoRegions
                .map(\.identifier)
                .filter { $0.count == 2 }   // countries — continents/macroregions are numeric (e.g. "150")
        return codes.sorted { regionName($0) < regionName($1) }
    }

    private func regionName(_ code: String) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    /// Non-TextInput fields whose canonical value (ISO-8601 / rawValue) differs
    /// from the displayed text — live re-validation runs from `formValues`.
    private static let canonicalRevalidated: [PassengerFormField] = [.gender, .dateOfBirth, .nationality, .documentExpiry]

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let customHeader {
                customHeader
            } else {
                titleHeader
            }

            if !personalFields.isEmpty {
                Fieldset(String(themeKitTravel: "Personal details")) {
                    ForEach(personalFields, id: \.self) { field(for: $0) }
                }
            }

            if !documentFields.isEmpty {
                Fieldset(String(themeKitTravel: "Travel document")) {
                    ForEach(documentFields, id: \.self) { field(for: $0) }
                }
            }

            if let customFooter { customFooter }
        }
        .tint(accent?.base)
        // Live canonical re-validation for the select/date fields (see header
        // note): same gate as `.field(_:in:)` — only once the form has
        // validated the field (a failed submit or a prior live pass).
        .onChange(of: draft) { _, newDraft in
            guard let form else { return }
            let values = newDraft.formValues
            for field in Self.canonicalRevalidated
            where fieldList.contains(field) && form.messages.index(forKey: field) != nil {
                form.validate(field, values[field] ?? "")
            }
        }
        // A labeled container: VoiceOver announces the traveler ("Passenger 1,
        // Adult") before stepping into the fields, which self-label.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    // MARK: Sub-views

    private var titleHeader: some View {
        Text(title)
            .textStyle(.headingSm)
            .foregroundStyle(theme.text(.textPrimary))
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func field(for field: PassengerFormField) -> some View {
        switch field {
        case .givenName: givenNameField
        case .familyName: familyNameField
        case .gender: genderField
        case .dateOfBirth: birthDateField
        case .nationality: nationalityField
        case .documentNumber: documentNumberField
        case .documentExpiry: documentExpiryField
        }
    }

    private var givenNameField: some View {
        var input = TextInput(String(themeKitTravel: "Given name"), text: $draft.givenName)
            .keyboard(contentType: .givenName, submit: .next, capitalization: .words)
            .a11yID("passenger-form.given-name")
        if let form { input = input.field(.givenName, in: form) }
        return input
    }

    private var familyNameField: some View {
        var input = TextInput(String(themeKitTravel: "Family name"), text: $draft.familyName)
            .keyboard(contentType: .familyName, submit: .next, capitalization: .words)
            .a11yID("passenger-form.family-name")
        if let form { input = input.field(.familyName, in: form) }
        return input
    }

    private var genderField: some View {
        var box = SelectBox(String(themeKitTravel: "Gender"),
                            options: PassengerGender.allCases,
                            selection: $draft.gender) { $0.label }
            .a11yID("passenger-form.gender")
        if let form {
            box = box.infoMessages(form.messages(for: .gender))
                .externalFocus(form.focusBinding(.gender))
        }
        return box
    }

    private var birthDateField: some View {
        var field = DateField(String(themeKitTravel: "Date of birth"), date: $draft.dateOfBirth)
            .range(birthRange)
            .a11yID("passenger-form.date-of-birth")
        if let form {
            field = field.infoMessages(form.messages(for: .dateOfBirth))
                .externalFocus(form.focusBinding(.dateOfBirth))
        }
        return field
    }

    private var nationalityField: some View {
        var box = SelectBox(String(themeKitTravel: "Nationality"),
                            options: nationalityCodes,
                            selection: $draft.nationality) { regionName($0) }
            .a11yID("passenger-form.nationality")
        if let form {
            box = box.infoMessages(form.messages(for: .nationality))
                .externalFocus(form.focusBinding(.nationality))
        }
        return box
    }

    private var documentNumberField: some View {
        var input = TextInput(String(themeKitTravel: "Document number"), text: $draft.documentNumber)
            .keyboard(submit: .next, capitalization: .characters)
            .required(isDocumentRequired)
            .a11yID("passenger-form.document-number")
        if let form {
            input = input.field(.documentNumber, in: form)
        } else if isDocumentRequired {
            // No form brain wired — the rule pack runs field-locally instead.
            input = input.validate([.required(), .documentNumber])
        }
        return input
    }

    private var documentExpiryField: some View {
        var field = DateField(String(themeKitTravel: "Document expiry"), date: $draft.documentExpiry)
            .range(expiryRange)   // picker prevents past dates; trip-date policy is the validator's
            .required(isDocumentRequired)
            .a11yID("passenger-form.document-expiry")
        if let form {
            field = field.infoMessages(form.messages(for: .documentExpiry))
                .externalFocus(form.focusBinding(.documentExpiry))
        } else if isDocumentRequired {
            field = field.validate([.required()])
        }
        return field
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PassengerForm {
    /// Which fields render, in order (default: all). Absent fields aren't
    /// rendered — and a wired validator only receives live re-validation for
    /// rendered fields (declare rules only for what you render).
    func fields(_ list: [PassengerFormField]) -> Self { copy { $0.fieldList = list } }

    /// Nationality options as ISO 3166-1 region codes (default: all ISO
    /// regions). Display names resolve via the environment `Locale`; the list
    /// is sorted by localized name either way.
    func nationalities(_ regions: [String]) -> Self { copy { $0.explicitNationalities = regions } }

    /// Renders document number + expiry as required — asterisks on both, and
    /// (only when no `validator(_:)` is wired) the rule pack runs field-locally:
    /// `.required() + .documentNumber` on the number, `.required()` plus a
    /// future-only picker window on the expiry. With a validator wired, declare
    /// the rules there instead (see the type-level example) — the form never
    /// double-validates.
    func documentRequired(_ on: Bool = true) -> Self { copy { $0.isDocumentRequired = on } }

    /// Selectable date-of-birth window (default: 120 years back … today).
    /// The picker clamps to it.
    func birthDateRange(_ range: ClosedRange<Date>) -> Self { copy { $0.explicitBirthRange = range } }

    /// Wires every rendered field into the given validator (ADR-F6): messages,
    /// focus and live re-validation flow through it, keyed by
    /// `PassengerFormField`. Submission stays app-side:
    /// `if form.validateAll(draft.formValues) == nil { … }`.
    func validator(_ form: FormValidator<PassengerFormField>) -> Self { copy { $0.form = form } }

    /// Accent tint for the interactive chrome (date pickers, menu checkmarks).
    /// `nil` inherits the surrounding tint.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Replaces the built-in title row.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.customHeader = AnyView(content()) } }

    /// Bottom-aligned accessory area under the fieldsets.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.customFooter = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("PassengerForm — validator wired") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State private var traveler = PassengerDraft()
        @State private var accepted = false
        @State private var form = FormValidator<PassengerFormField>([
            .givenName: [.required()],
            .familyName: [.required()],
            .gender: [.required()],
            .dateOfBirth: [.required()],
            .documentNumber: [.required(), .documentNumber],
            .documentExpiry: [.required(), .expiryInFuture()],
        ])

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                    PassengerForm("Passenger 1 · Adult", draft: $traveler)
                        .documentRequired()
                        .validator(form)
                        .footer {
                            Text("Enter the name exactly as printed on the travel document.")
                                .textStyle(.bodySm400)
                                .foregroundStyle(theme.text(.textTertiary))
                        }

                    PrimaryButton("Continue") {
                        // §1.4 rev 4 — submission via validateAll + canonical formValues:
                        accepted = form.validateAll(traveler.formValues) == nil
                    }
                    .fullWidth()

                    if accepted {
                        Text("Traveler accepted.")
                            .textStyle(.labelSm600)
                            .foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
                    }
                }
                .padding()
            }
            .background(theme.background(.bgBase))
        }
    }
    return Demo()
}

#Preview("Variants — fields · accent · header · standalone rules") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State private var minimal = PassengerDraft()
        @State private var domestic = PassengerDraft()

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    // Domestic subset — no travel document, custom header, accent:
                    PassengerForm("Traveler", draft: $domestic)
                        .fields([.givenName, .familyName, .dateOfBirth])
                        .accent(.accent)
                        .header {
                            HStack(spacing: Theme.SpacingKey.sm.value) {
                                Icon(systemName: "person.text.rectangle")
                                Text("Lead traveler").textStyle(.headingSm)
                            }
                        }

                    // No validator — documentRequired runs the rule pack field-locally:
                    PassengerForm("Passenger 2 · Adult", draft: $minimal)
                        .documentRequired()
                        .nationalities(["DE", "FR", "JP", "BR", "NO"])
                        .birthDateRange(Date.distantPast...Date.now)
                }
                .padding()
            }
            .background(theme.background(.bgBase))
        }
    }
    return Demo()
}

#Preview("Dark") {
    struct Demo: View {
        @State private var traveler = PassengerDraft()
        var body: some View {
            ScrollView {
                PassengerForm("Passenger 1 · Adult", draft: $traveler)
                    .documentRequired()
                    .padding()
            }
            .background(Theme.shared.background(.bgBase))
            .onAppear { Theme.shared.loadTheme(named: Theme.defaultThemeName, dark: true) }
            .onDisappear { Theme.shared.loadTheme(named: Theme.defaultThemeName, dark: false) }
        }
    }
    return Demo()
}
