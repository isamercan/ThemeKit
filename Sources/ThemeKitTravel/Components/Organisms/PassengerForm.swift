//
//  PassengerForm.swift
//  ThemeKitTravel
//
//  Organism (§9.2, P0). The editable traveler-details form — name / gender /
//  date of birth / nationality / travel document — bound to a `PassengerDraft`.
//  Distinct from `PassengerRow` (a display row for review screens).
//
//  Composes neutral ThemeKit fields (`TextInput`, `SelectBox`, `DateField`);
//  all of them inherit `FieldDefaults` / `FieldStyle` from the environment,
//  so the form re-skins with the subtree's field chrome. Section chrome
//  (`Fieldset`, `Card`, or none) is now the ``PassengerFormStyle`` axis below.
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
//  Style (ADR-0004, Class B): the component owns every live field unit
//  (bindings, validator wiring, focus) — arrangement is delegated to the
//  active ``PassengerFormStyle`` (`PassengerFormStyle.swift`) via
//  `.passengerFormStyle(_:)`. `.stacked`/`.flat`/`.grouped` are the former
//  `PassengerFormLayout` cases, deprecate-forwarded through `.layout(_:)`;
//  `.carded` is new. Validation, live re-validation, the `.tint(_:)` accent
//  and the container accessibility label stay applied by the component
//  around the style's output — styles only arrange pre-wired field-run units.
//

import SwiftUI
import ThemeKit

// MARK: - PassengerFormField

/// The form's field keys — `FormValidator` keys, `formValues` keys, and the
/// `fields(_:)` render list all speak this vocabulary.
public enum PassengerFormField: Hashable, Sendable, CaseIterable {
    case givenName, familyName, gender, dateOfBirth, nationality, documentNumber, documentExpiry
}

// MARK: - PassengerFormLayout

/// Section chrome of a ``PassengerForm``: two `Fieldset`s (`.stacked`, the
/// default), bare fields with plain section titles (`.flat`), or every field
/// inside one `Fieldset` (`.grouped`).
///
/// Superseded by ``PassengerFormStyle`` (ADR-0004) — every case maps 1:1
/// onto a preset (`.stacked` → `.passengerFormStyle(.stacked)` and so on,
/// plus the new `.carded`); the enum remains for source compatibility via
/// the deprecated ``PassengerForm/layout(_:)`` and is removed at the next
/// major.
public enum PassengerFormLayout: Sendable { case stacked, flat, grouped }

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.componentDensity) private var envDensity
    @Environment(\.passengerFormStyle) private var envStyle

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
    /// Per-field title overrides (`label(_:for:)`); absent = built-in title.
    private var labelOverrides: [PassengerFormField: String] = [:]
    /// Section titles: `nil` = built-in, `""` = section renders without a title.
    private var personalTitleOverride: String?
    private var documentTitleOverride: String?
    /// Style set by the deprecated `.layout(_:)`; wins over the environment
    /// style (ADR-0004 §5 — source-behavior stability during migration).
    private var explicitStyle: AnyPassengerFormStyle?
    /// Extra caller fields appended after the document section.
    private var additionalFieldsSlot: AnyView?
    private var genderOptions: [PassengerGender] = Array(PassengerGender.allCases)
    private var columnsValue = 1

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
        // The arrangement is owned by the active `PassengerFormStyle`
        // (ADR-0004 Class B): the field-run units below are pre-wired and
        // fully interactive (bindings, validator wiring, focus); the style
        // arranges them, never re-wires them.
        let configuration = PassengerFormConfiguration(
            personalFields: personalFields.isEmpty ? nil : AnyView(fieldRun(personalFields)),
            documentFields: documentFields.isEmpty ? nil : AnyView(fieldRun(documentFields)),
            groupedFields: fieldList.isEmpty ? nil : AnyView(fieldRun(fieldList)),
            header: customHeader ?? AnyView(titleHeader),
            footer: customFooter,
            additionalFields: additionalFieldsSlot,
            personalTitle: resolvedPersonalTitle,
            documentTitle: resolvedDocumentTitle,
            groupedTitle: resolvedGroupedTitle,
            accent: accent,
            density: envDensity,
            locale: locale)
        let style = explicitStyle ?? envStyle   // explicit (deprecated .layout) wins — ADR-0004 §5
        return style.makeBody(configuration: configuration)
            .tint(accent.map { theme.resolve($0).base })
            // Live canonical re-validation for the select/date fields (see
            // header note): same gate as `.field(_:in:)` — only once the
            // form has validated the field (a failed submit or a prior
            // live pass).
            .onChangeCompat(of: draft) { _, newDraft in
                guard let form else { return }
                let values = newDraft.formValues
                for field in Self.canonicalRevalidated
                where fieldList.contains(field) && form.messages.index(forKey: field) != nil {
                    form.validate(field, values[field] ?? "")
                }
            }
            // A labeled container: VoiceOver announces the traveler
            // ("Passenger 1, Adult") before stepping into the fields, which
            // self-label.
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

    // MARK: Sections (layout + titles + column pairing)

    /// `nil` = render the section without a title (`sectionTitles` passed "").
    private var resolvedPersonalTitle: String? {
        switch personalTitleOverride {
        case nil: return String(themeKitTravel: "Personal details")
        case "": return nil
        case let custom: return custom
        }
    }

    private var resolvedDocumentTitle: String? {
        switch documentTitleOverride {
        case nil: return String(themeKitTravel: "Travel document")
        case "": return nil
        case let custom: return custom
        }
    }

    /// `.grouped` merges both sections under one `Fieldset` — an explicit
    /// personal title wins, otherwise a merged default.
    private var resolvedGroupedTitle: String? {
        switch personalTitleOverride {
        case nil: return String(themeKitTravel: "Traveler details")
        case "": return nil
        case let custom: return custom
        }
    }

    /// Whether the given/family pair renders side-by-side: `columns(2)` asked
    /// for it, both names are in the run, and the type size isn't an
    /// accessibility size (those always stack).
    private func pairsNames(in fields: [PassengerFormField]) -> Bool {
        columnsValue >= 2
            && !dynamicTypeSize.isAccessibilitySize
            && fields.contains(.givenName)
            && fields.contains(.familyName)
    }

    /// The ordered fields; when pairing, the two name fields collapse into one
    /// `ViewThatFits` row at the first name's position (narrow widths fall
    /// back to stacked automatically).
    @ViewBuilder
    private func fieldRun(_ fields: [PassengerFormField]) -> some View {
        let pairing = pairsNames(in: fields)
        let secondName: PassengerFormField? = pairing
            ? [PassengerFormField.givenName, .familyName]
                .max { (fields.firstIndex(of: $0) ?? 0) < (fields.firstIndex(of: $1) ?? 0) }
            : nil
        ForEach(fields, id: \.self) { key in
            if pairing, key == .givenName || key == .familyName {
                if key != secondName {   // render the pair once, skip the later twin
                    namePairRow
                }
            } else {
                field(for: key)
            }
        }
    }

    /// Given/family side-by-side when they fit; stacked otherwise.
    private var namePairRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                givenNameField
                familyNameField
            }
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                givenNameField
                familyNameField
            }
        }
    }

    /// The field's title: the `label(_:for:)` override or the built-in string.
    private func fieldTitle(_ field: PassengerFormField) -> String {
        if let override = labelOverrides[field] { return override }
        switch field {
        case .givenName: return String(themeKitTravel: "Given name")
        case .familyName: return String(themeKitTravel: "Family name")
        case .gender: return String(themeKitTravel: "Gender")
        case .dateOfBirth: return String(themeKitTravel: "Date of birth")
        case .nationality: return String(themeKitTravel: "Nationality")
        case .documentNumber: return String(themeKitTravel: "Document number")
        case .documentExpiry: return String(themeKitTravel: "Document expiry")
        }
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
        var input = TextInput(fieldTitle(.givenName), text: $draft.givenName)
            .keyboard(contentType: .givenName, submit: .next, capitalization: .words)
            .a11yID("passenger-form.given-name")
        if let form { input = input.field(.givenName, in: form) }
        return input
    }

    private var familyNameField: some View {
        var input = TextInput(fieldTitle(.familyName), text: $draft.familyName)
            .keyboard(contentType: .familyName, submit: .next, capitalization: .words)
            .a11yID("passenger-form.family-name")
        if let form { input = input.field(.familyName, in: form) }
        return input
    }

    private var genderField: some View {
        var box = SelectBox(fieldTitle(.gender),
                            options: genderOptions,
                            selection: $draft.gender) { $0.label }
            .a11yID("passenger-form.gender")
        if let form {
            box = box.infoMessages(form.messages(for: .gender))
                .externalFocus(form.focusBinding(.gender))
        }
        return box
    }

    private var birthDateField: some View {
        var field = DateField(fieldTitle(.dateOfBirth), date: $draft.dateOfBirth)
            .range(birthRange)
            .a11yID("passenger-form.date-of-birth")
        if let form {
            field = field.infoMessages(form.messages(for: .dateOfBirth))
                .externalFocus(form.focusBinding(.dateOfBirth))
        }
        return field
    }

    private var nationalityField: some View {
        var box = SelectBox(fieldTitle(.nationality),
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
        var input = TextInput(fieldTitle(.documentNumber), text: $draft.documentNumber)
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
        var field = DateField(fieldTitle(.documentExpiry), date: $draft.documentExpiry)
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

    /// Overrides one field's built-in title (e.g. "First name" for
    /// `.givenName`). Chain once per field; unset fields keep their defaults.
    func label(_ text: String, for field: PassengerFormField) -> Self {
        copy { $0.labelOverrides[field] = text }
    }

    /// Overrides the section titles. `nil` keeps the built-in title
    /// ("Personal details" / "Travel document"); an empty string hides the
    /// title while keeping the section. In `.grouped` the personal title
    /// names the single fieldset.
    func sectionTitles(personal: String? = nil, document: String? = nil) -> Self {
        copy {
            $0.personalTitleOverride = personal
            $0.documentTitleOverride = document
        }
    }

    /// Section chrome: `.stacked` (two `Fieldset`s, default), `.flat` (bare
    /// fields + plain titles, no fieldset chrome), or `.grouped` (everything
    /// in one `Fieldset`). Maps 1:1 onto the ``PassengerFormStyle`` presets
    /// and, when called, wins over the environment style (source-behavior
    /// stability during migration — ADR-0004 §5).
    @available(*, deprecated, message: "Use .passengerFormStyle(_:) — e.g. .passengerFormStyle(.flat)")
    func layout(_ l: PassengerFormLayout) -> Self {
        copy {
            switch l {
            case .stacked: $0.explicitStyle = AnyPassengerFormStyle(StackedPassengerFormStyle())
            case .flat: $0.explicitStyle = AnyPassengerFormStyle(FlatPassengerFormStyle())
            case .grouped: $0.explicitStyle = AnyPassengerFormStyle(GroupedPassengerFormStyle())
            }
        }
    }

    /// Extra caller-owned fields appended after the document section (before
    /// the footer) — e.g. a frequent-flyer number. The slot inherits the
    /// subtree's `FieldStyle`/`FieldDefaults`; validation of slot fields is
    /// the caller's.
    func additionalFields<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.additionalFieldsSlot = AnyView(content()) }
    }

    /// The gender selector's options (default: all ``PassengerGender`` cases)
    /// — e.g. `[.female, .male]` for carriers that don't file "Unspecified".
    func genders(_ options: [PassengerGender]) -> Self {
        copy { $0.genderOptions = options.isEmpty ? Array(PassengerGender.allCases) : options }
    }

    /// `2` renders given/family side-by-side (via `ViewThatFits`, so narrow
    /// widths still stack); accessibility type sizes always fall back to
    /// stacked. Default `1`.
    func columns(_ n: Int) -> Self { copy { $0.columnsValue = min(2, max(1, n)) } }

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

#Preview("Layouts · labels · columns · genders · extra fields") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State private var flat = PassengerDraft()
        @State private var grouped = PassengerDraft()
        @State private var loyalty = ""

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    // Flat style, custom labels, side-by-side names, trimmed genders.
                    PassengerForm("Traveler 1", draft: $flat)
                        .columns(2)
                        .label("First name", for: .givenName)
                        .label("Last name", for: .familyName)
                        .genders([.female, .male])
                        .sectionTitles(personal: "Who is flying?", document: "")
                        .passengerFormStyle(.flat)

                    // Grouped style + additional caller field after the documents.
                    PassengerForm("Traveler 2", draft: $grouped)
                        .sectionTitles(personal: "Traveler details")
                        .additionalFields {
                            TextInput("Frequent flyer number", text: $loyalty)
                                .keyboard(capitalization: .characters)
                        }
                        .passengerFormStyle(.grouped)
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
