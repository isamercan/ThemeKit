//
//  PassengerFormStyle.swift
//  ThemeKitTravel
//
//  The styling hook for ``PassengerForm`` — a Class B protocol of ADR-0004
//  (per-component style protocols). The component owns the live field units
//  (bindings, `FormValidator` wiring, focus) — the configuration hands
//  styles **pre-wired, type-erased field-unit runs** (one per section) plus
//  typed signals (section titles, accent, density, locale). Styles ARRANGE
//  the units; they never rebuild or re-wire them. Four built-ins:
//
//    .stacked   two `Fieldset`s (personal details, travel document) —
//               today's render. Default.
//    .flat      the same two sections with plain titles, no `Fieldset`
//               chrome.
//    .grouped   every rendered field under one legend, in one `Fieldset`.
//    .carded    each non-empty section in its own `Card`.
//
//      PassengerForm("Passenger 1 · Adult", draft: $traveler)
//          .documentRequired()
//          .validator(form)
//          .passengerFormStyle(.carded)
//
//  One law (ADR-0004 §6): the component style arranges *content*; shell
//  components (`Fieldset`/`Card`) paint their own chrome; the token theme
//  colors everything. Validation (ADR-F6), live canonical re-validation, the
//  `.tint(_:)` accent and the container accessibility label are all applied
//  by the component *around* the style's output (see `PassengerForm.body`)
//  — styles never touch validator state and never need to re-apply the tint.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The pre-wired inputs a ``PassengerFormStyle`` arranges. The `AnyView`
/// field-run units are fully interactive (text fields, selects, date pickers
/// already bound to the draft and wired into the validator) — place them,
/// never rebuild them. The typed fields are read-only signals for
/// arrangement decisions; the field wiring and validator state never leave
/// the component.
public struct PassengerFormConfiguration {
    // Pre-wired field units — fully interactive; styles arrange, never re-wire.
    /// The personal-details field run (name / gender / date of birth /
    /// nationality, in `fields(_:)` order); `nil` when none of those fields
    /// are rendered.
    public let personalFields: AnyView?
    /// The travel-document field run (number / expiry, in `fields(_:)`
    /// order); `nil` when neither is rendered.
    public let documentFields: AnyView?
    /// Every rendered field in one run, in raw `fields(_:)` order (spans
    /// both sections, unsplit) — the unit a single-legend arrangement
    /// (``groupedTitle``) presents. `nil` when no fields are rendered.
    public let groupedFields: AnyView?
    /// The title header — the `.header { }` slot content, or the built-in
    /// title `Text`; always present. Arrange it, never rebuild it.
    public let header: AnyView
    /// Bottom-aligned accessory area (`.footer { }`); `nil` = none.
    public let footer: AnyView?
    /// Extra caller-owned fields (`.additionalFields { }`), appended after
    /// the document section; `nil` = none. Inherits the subtree's
    /// `FieldStyle`/`FieldDefaults`; validation of slot fields is the
    /// caller's.
    public let additionalFields: AnyView?

    // Typed signals for arrangement decisions.
    /// Resolved personal-section legend for ``personalFields``; `nil`
    /// renders the section without a title (`sectionTitles(personal: "")`
    /// asked for that).
    public let personalTitle: String?
    /// Resolved document-section legend for ``documentFields``; same `nil`
    /// convention as ``personalTitle``.
    public let documentTitle: String?
    /// Resolved single legend for ``groupedFields``.
    public let groupedTitle: String?
    /// Accent tint (`accent(_:)`); `nil` inherits the surrounding tint. The
    /// component already applies it via `.tint(_:)` around the whole style
    /// output, so built-in presets don't need to re-apply it — it's exposed
    /// for a custom style's own chrome (e.g. an accented section border).
    public let accent: SemanticColor?
    /// The environment's component density, captured by the component —
    /// scale a preset's own chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component.
    public let locale: Locale

    /// Density-scaled spacing — use for a preset's own chrome padding/gaps
    /// so `.componentDensity` compacts or airs it out (the field units
    /// already scale their own internals).
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
}

// MARK: - Protocol

/// Defines a `PassengerForm`'s entire presentation. Implement `makeBody` to
/// arrange the configuration's pre-wired field-unit runs. Set one with
/// `.passengerFormStyle(_:)`; the default is ``StackedPassengerFormStyle``.
public protocol PassengerFormStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: PassengerFormConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// `Fieldset` chrome (or a plain labeled stack for chrome-less / title-less
/// sections) around a pre-wired field-run unit — shared by `.stacked` and
/// `.flat`, the exact anatomy `PassengerForm` rendered before this style
/// existed. `title == nil` (an explicit `sectionTitles(…: "")`) always
/// drops the `Fieldset` chrome too, matching the pre-style behavior.
private struct PassengerFormSection: View {
    @Environment(\.theme) private var theme
    let title: String?
    let unit: AnyView
    var chrome = true

    var body: some View {
        if chrome, let title {
            Fieldset(title) { unit }
        } else {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                if let title {
                    Text(title)
                        .textStyle(.labelBase700)
                        .foregroundStyle(theme.text(.textPrimary))
                        .accessibilityAddTraits(.isHeader)
                }
                unit
            }
        }
    }
}

// MARK: - .stacked (default)

/// Today's `PassengerForm` look, extracted verbatim: the title header, a
/// `Fieldset` for personal details, a `Fieldset` for the travel document,
/// the additional-fields slot, then the footer.
public struct StackedPassengerFormStyle: PassengerFormStyle {
    public init() {}
    public func makeBody(configuration c: PassengerFormConfiguration) -> some View {
        VStack(alignment: .leading, spacing: c.spacing(.md)) {
            c.header
            if let personalFields = c.personalFields {
                PassengerFormSection(title: c.personalTitle, unit: personalFields)
            }
            if let documentFields = c.documentFields {
                PassengerFormSection(title: c.documentTitle, unit: documentFields)
            }
            if let additionalFields = c.additionalFields { additionalFields }
            if let footer = c.footer { footer }
        }
    }
}

// MARK: - .flat

/// The same two sections as `.stacked`, without `Fieldset` chrome — a plain
/// label above each field run instead of a bordered box.
public struct FlatPassengerFormStyle: PassengerFormStyle {
    public init() {}
    public func makeBody(configuration c: PassengerFormConfiguration) -> some View {
        VStack(alignment: .leading, spacing: c.spacing(.md)) {
            c.header
            if let personalFields = c.personalFields {
                PassengerFormSection(title: c.personalTitle, unit: personalFields, chrome: false)
            }
            if let documentFields = c.documentFields {
                PassengerFormSection(title: c.documentTitle, unit: documentFields, chrome: false)
            }
            if let additionalFields = c.additionalFields { additionalFields }
            if let footer = c.footer { footer }
        }
    }
}

// MARK: - .grouped

/// Every rendered field under one legend, in one `Fieldset` — no split
/// between personal details and the travel document.
public struct GroupedPassengerFormStyle: PassengerFormStyle {
    public init() {}
    public func makeBody(configuration c: PassengerFormConfiguration) -> some View {
        VStack(alignment: .leading, spacing: c.spacing(.md)) {
            c.header
            if let groupedFields = c.groupedFields {
                PassengerFormSection(title: c.groupedTitle, unit: groupedFields)
            }
            if let additionalFields = c.additionalFields { additionalFields }
            if let footer = c.footer { footer }
        }
    }
}

// MARK: - .carded

/// Each non-empty section in its own `Card` — a more separated look for
/// screens that already use `Card` for other booking-flow blocks.
public struct CardedPassengerFormStyle: PassengerFormStyle {
    public init() {}
    public func makeBody(configuration c: PassengerFormConfiguration) -> some View {
        VStack(alignment: .leading, spacing: c.spacing(.md)) {
            c.header
            if let personalFields = c.personalFields {
                Card(c.personalTitle) { personalFields }
                    .contentPadding(.md)
            }
            if let documentFields = c.documentFields {
                Card(c.documentTitle) { documentFields }
                    .contentPadding(.md)
            }
            if let additionalFields = c.additionalFields { additionalFields }
            if let footer = c.footer { footer }
        }
    }
}

// MARK: - Static accessors

public extension PassengerFormStyle where Self == StackedPassengerFormStyle {
    /// Two `Fieldset`s (personal details, travel document) — today's render.
    /// The default.
    static var stacked: StackedPassengerFormStyle { StackedPassengerFormStyle() }
}
public extension PassengerFormStyle where Self == FlatPassengerFormStyle {
    /// The same two sections, with plain titles instead of `Fieldset` chrome.
    static var flat: FlatPassengerFormStyle { FlatPassengerFormStyle() }
}
public extension PassengerFormStyle where Self == GroupedPassengerFormStyle {
    /// Every rendered field under one legend, in one `Fieldset`.
    static var grouped: GroupedPassengerFormStyle { GroupedPassengerFormStyle() }
}
public extension PassengerFormStyle where Self == CardedPassengerFormStyle {
    /// Each non-empty section in its own `Card`.
    static var carded: CardedPassengerFormStyle { CardedPassengerFormStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyPassengerFormStyle: PassengerFormStyle {
    private let _makeBody: @MainActor (PassengerFormConfiguration) -> AnyView
    init<S: PassengerFormStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: PassengerFormConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct PassengerFormStyleKey: EnvironmentKey {
    static let defaultValue = AnyPassengerFormStyle(StackedPassengerFormStyle())
}

extension EnvironmentValues {
    var passengerFormStyle: AnyPassengerFormStyle {
        get { self[PassengerFormStyleKey.self] }
        set { self[PassengerFormStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``PassengerFormStyle`` for `PassengerForm`s in this view and
    /// its descendants — a booking flow can run `.carded` while a dense
    /// review step keeps `.flat`.
    func passengerFormStyle<S: PassengerFormStyle>(_ style: sending S) -> some View {
        environment(\.passengerFormStyle, AnyPassengerFormStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — a two-column layout that
/// places the personal and document sections side by side. Proves external
/// implementability: it never touches field wiring, only arranges the
/// pre-wired units.
private struct SplitPassengerFormStyle: PassengerFormStyle {
    func makeBody(configuration: PassengerFormConfiguration) -> some View {
        SplitChrome(configuration: configuration)
    }

    private struct SplitChrome: View {
        @Environment(\.theme) private var theme
        let configuration: PassengerFormConfiguration

        var body: some View {
            VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
                configuration.header
                HStack(alignment: .top, spacing: configuration.spacing(.md)) {
                    if let personalFields = configuration.personalFields {
                        column(title: configuration.personalTitle, unit: personalFields)
                    }
                    if let documentFields = configuration.documentFields {
                        column(title: configuration.documentTitle, unit: documentFields)
                    }
                }
                if let additionalFields = configuration.additionalFields { additionalFields }
                if let footer = configuration.footer { footer }
            }
        }

        private func column(title: String?, unit: AnyView) -> some View {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                if let title {
                    Text(title)
                        .textStyle(.overline500)
                        .foregroundStyle(theme.text(.textTertiary))
                }
                unit
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Preview-only harness: owns the `@State` draft each interactive case binds to.
private struct PassengerFormStyleHarness<Content: View>: View {
    @State private var draft: PassengerDraft
    private let content: (Binding<PassengerDraft>) -> Content

    init(_ draft: PassengerDraft, @ViewBuilder content: @escaping (Binding<PassengerDraft>) -> Content) {
        self._draft = State(initialValue: draft)
        self.content = content
    }

    var body: some View { content($draft) }
}

private func styleDraft() -> PassengerDraft {
    var draft = PassengerDraft()
    draft.givenName = "Ada"
    draft.familyName = "Lovelace"
    draft.gender = .female
    draft.dateOfBirth = Calendar.current.date(byAdding: .year, value: -34, to: .now)
    draft.nationality = "GB"
    draft.documentNumber = "X1234567"
    draft.documentExpiry = Calendar.current.date(byAdding: .year, value: 5, to: .now)
    return draft
}

#Preview("PassengerFormStyle — presets × light/dark") {
    PreviewMatrix("PassengerFormStyle") {
        PreviewCase(".stacked (default)") {
            PassengerFormStyleHarness(styleDraft()) {
                PassengerForm("Passenger 1 · Adult", draft: $0).documentRequired()
            }
        }
        PreviewCase(".flat") {
            PassengerFormStyleHarness(styleDraft()) {
                PassengerForm("Passenger 1 · Adult", draft: $0)
                    .documentRequired()
                    .passengerFormStyle(.flat)
            }
        }
        PreviewCase(".grouped") {
            PassengerFormStyleHarness(styleDraft()) {
                PassengerForm("Passenger 1 · Adult", draft: $0)
                    .documentRequired()
                    .passengerFormStyle(.grouped)
            }
        }
        PreviewCase(".carded") {
            PassengerFormStyleHarness(styleDraft()) {
                PassengerForm("Passenger 1 · Adult", draft: $0)
                    .documentRequired()
                    .passengerFormStyle(.carded)
            }
        }
        PreviewCase("Custom (in-preview) — split columns") {
            PassengerFormStyleHarness(styleDraft()) {
                PassengerForm("Passenger 1 · Adult", draft: $0)
                    .documentRequired()
                    .passengerFormStyle(SplitPassengerFormStyle())
            }
        }
    }
}
