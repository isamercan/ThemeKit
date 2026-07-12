//
//  TripSearchCard.swift
//  ThemeKitTravel
//
//  Capstone edition organism (F2.3 · §9.6). The all-in-one flight-search card:
//  trip type, origin/destination with swap, dates, passengers, cabin, CTA.
//  This is the "extend" item — it COMPOSES the existing molecule set rather
//  than duplicating any of it:
//
//    TripTypeToggle → AirportPicker (`.sheet`) ×2 + SwapButton → DateField ×1–2
//    → FieldButton + GuestSelector (bottom sheet) → CabinClassSelector
//    → PrimaryButton CTA → optional `.promo { }` slot.
//
//  The *arrangement* is owned by the active ``TripSearchCardStyle`` from the
//  environment (ADR-0004, Class B): the component builds fully-wired field
//  units (bindings, sheets, swap spin, debounced lookups) plus typed signals
//  into a ``TripSearchCardConfiguration`` and hands it to the style — `.card`
//  (default) is today's stacked editor verbatim; `.hero`, `.compact`,
//  `.inlineBar` and `.pill` swap the whole layout, and apps can implement
//  their own. Card-shaped styles keep composing the neutral `Card`, which
//  routes `surface` / `elevation` through `CardStyleConfiguration` — so
//  `.cardStyle(_:)` set on the subtree still re-chromes this card exactly
//  like every other card-shaped organism.
//
//  Multi-city (decided in-PR, per the §9.6 "only if cheap" note): `.multiCity`
//  is accepted in the model and selectable in the toggle, but v1 renders the
//  single-slice editor (origin → destination + departure date, no return date
//  — the same anatomy as `.oneWay`). A dedicated multi-leg editor (add/remove
//  slices) is a follow-up organism; building it here would triple the file and
//  couple this card to a leg-list model the plan hasn't specified yet.
//
//  House rules: the component never performs the airport lookup itself — the
//  caller owns it and feeds `airports(suggestions:…)`, plumbed straight into
//  the embedded `AirportPicker`s together with the debounced `onAirportQuery`.
//

import SwiftUI
import ThemeKit

// MARK: - Variant (deprecated toward TripSearchCardStyle)

/// How ``TripSearchCard`` presents. Superseded by ``TripSearchCardStyle``
/// (ADR-0004) — every case maps 1:1 to a preset (`.card` →
/// `.tripSearchCardStyle(.card)` and so on, plus the new `.pill`); the enum
/// remains for source compatibility and is removed at the next major.
public enum TripSearchVariant: Sendable { case card, hero, compact, inlineBar }

/// Vertical density of the editor: `.regular` (default) or `.compact` —
/// tighter stacks resolved from spacing tokens.
public enum TripSearchDensity: Sendable { case compact, regular }

// MARK: - TripSearchCard

/// Organism. The all-in-one flight-search card — trip type, origin/destination
/// with swap, dates, passengers, cabin and a search CTA — bound to a single
/// controlled ``TripSearchDraft``.
///
/// ```swift
/// @State private var draft = TripSearchDraft()
///
/// TripSearchCard(draft: $draft) { search($0) }
///     .airports(suggestions: results, recent: store.recents, popular: curated)
///     .onAirportQuery { lookup($0) }
///     .tripSearchCardStyle(.hero)
///     .promo { PromoBanner("Summer sale") }
/// ```
///
/// - Note: `.multiCity` renders the one-slice editor in v1 (origin →
///   destination + departure date); a multi-leg slice editor is a documented
///   follow-up. `.oneWay` hides the return `DateField` with `MicroMotion`-gated
///   motion, and the swap affordance calls `draft.swapRoute()`.
public struct TripSearchCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled     // R3 — set natively by `.disabled(_:)`
    /// Read-only subtree axis (set with `.readOnly(_:)`) — normal chrome, no edits/submits.
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.componentDensity) private var envDensity
    @Environment(\.tripSearchCardStyle) private var envStyle

    @Binding private var draft: TripSearchDraft
    private let onSearch: (TripSearchDraft) -> Void

    // Appearance/config — mutated only through the modifiers below (R2).
    private var suggestions: [Airport] = []
    private var recentAirports: [Airport] = []
    private var popularAirports: [Airport] = []
    private var airportQueryAction: ((String) -> Void)?
    private var explicitDateRange: ClosedRange<Date>?
    private var showsCabinPicker = true
    private var showsTripType = true
    private var ctaTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var ctaTitle: String { ctaTitleOverride ?? String(themeKitTravel: "Search flights") }
    /// Style set by the deprecated `.variant(_:)`; wins over the environment
    /// style (ADR-0004 §5 — source-behavior stability during migration).
    private var explicitStyle: AnyTripSearchCardStyle?
    /// `nil` → the style's own default surface (the built-ins use `.bgWhite`).
    private var surfaceKey: Theme.BackgroundColorKey?
    /// Explicit `.elevation(_:)` wins; otherwise the style picks (`.card`/
    /// `.compact`/`.inlineBar` → `.soft`, `.hero`/`.pill` → `.elevated`).
    private var explicitElevation: CardElevation?
    private var accentColor: SemanticColor?
    /// Promo slot under the CTA. Local erasure (ThemeKit's `SlotContent` is
    /// internal to that module); evaluated immediately at the modifier call
    /// site, so nothing escapes.
    private var promoContent: AnyView?
    /// Header slot above the editor (distinct from `.promo`).
    private var headerContent: AnyView?
    /// Footer slot below the editor (after `.promo`).
    private var footerContent: AnyView?
    /// Replaces the CTA button's built-in label; submit + disable wiring stay.
    private var ctaLabelContent: AnyView?
    private var densityValue: TripSearchDensity = .regular
    private var originIconName: String?
    private var destinationIconName: String?
    private var departureIconName: String?
    private var passengersIconName: String?
    private var showsSwapValue = true
    private var passengerDetents: [BottomSheetDetent] = [.medium]

    /// UI-only state (house rule 1): sheet + compact-expansion + swap spin.
    /// Class B contract: this never leaves the component — styles see only
    /// `isExpanded` and the motion-gated `toggleExpand`.
    @State private var isPassengerSheetPresented = false
    @State private var isExpanded = false
    @State private var swapAngle: Double = 0

    /// R1 — controlled draft + submit action (the one terminal command).
    public init(draft: Binding<TripSearchDraft>, onSearch: @escaping (TripSearchDraft) -> Void) {
        self._draft = draft
        self.onSearch = onSearch
    }

    // MARK: - Derived state

    private var motion: Animation? {
        MicroMotion.animation(enabled: micro, reduceMotion: reduceMotion)
    }

    /// Past dates are excluded by default (§9.6); an explicit `.dateRange(_:)` wins.
    private var effectiveDateRange: ClosedRange<Date> {
        explicitDateRange ?? Calendar.current.startOfDay(for: .now)...Date.distantFuture
    }

    /// The return picker never offers dates before the chosen departure
    /// (the draft self-heals the pair; the range keeps the picker honest).
    private var returnDateRange: ClosedRange<Date> {
        let window = effectiveDateRange
        let lower = min(max(window.lowerBound, draft.departureDate ?? window.lowerBound), window.upperBound)
        return lower...window.upperBound
    }

    private var showsReturnDate: Bool { draft.tripType == .roundTrip }

    /// CTA enablement: route + departure chosen; a round trip also needs a return.
    private var isDraftComplete: Bool {
        guard draft.origin != nil, draft.destination != nil, draft.departureDate != nil else { return false }
        return !showsReturnDate || draft.returnDate != nil
    }

    // MARK: - Body

    public var body: some View {
        // The arrangement is owned by the active `TripSearchCardStyle` (ADR-0004
        // Class B): the units below are pre-wired and fully interactive; the
        // style arranges them, never re-wires them. Motion is resolved *here*
        // (`toggleExpand` is animation-gated, and the expansion/trip-type
        // animations ride on the component) — styles never read the motion env.
        let configuration = TripSearchCardConfiguration(
            tripType: showsTripType ? AnyView(tripTypeToggle) : nil,
            routeFields: AnyView(routeFields),
            dateFields: AnyView(dateFields),
            passengersField: AnyView(passengersTrigger),
            cabinField: showsCabinPicker ? AnyView(cabinSection) : nil,
            cta: AnyView(ctaUnit(fullWidth: true, prominent: false)),
            heroCta: AnyView(ctaUnit(fullWidth: true, prominent: true)),
            inlineCta: AnyView(ctaUnit(fullWidth: false, prominent: false)),
            header: headerContent,
            promo: promoContent,
            footer: footerContent,
            draft: draft,
            isDraftComplete: isDraftComplete,
            isExpanded: isExpanded,
            toggleExpand: { withAnimation(motion) { isExpanded.toggle() } },
            accent: accentColor,
            surfaceKey: surfaceKey,
            elevation: explicitElevation,
            editorDensity: densityValue,
            density: envDensity,
            locale: locale)
        let style = explicitStyle ?? envStyle   // explicit (deprecated .variant) wins — ADR-0004 §5
        return style.makeBody(configuration: configuration)
            .animation(motion, value: isExpanded)
            // `.oneWay` hides the return field; gated by `microAnimations` + Reduce Motion.
            .animation(motion, value: draft.tripType)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(themeKitTravel: "Flight search"))
    }

    // MARK: Trip type (TripTypeToggle wrap — TripType ⇄ index)

    private var tripTypes: [TripType] { TripType.allCases }

    private var tripTypeBinding: Binding<Int> {
        Binding(
            get: { tripTypes.firstIndex(of: draft.tripType) ?? 0 },
            set: { index in
                guard tripTypes.indices.contains(index) else { return }
                draft.tripType = tripTypes[index]
            }
        )
    }

    private var tripTypeToggle: some View {
        TripTypeToggle(tripTypes.map(\.label), selection: tripTypeBinding)
            .icons(["arrow.right", "arrow.left.arrow.right", "point.3.connected.trianglepath.dotted"])
            .accent(accentColor)
            .allowsHitTesting(!isReadOnly)   // E1 — normal chrome, selection blocked
    }

    // MARK: Route (AirportPicker ×2 + SwapButton; ViewThatFits for a11y sizes)

    /// Horizontal at regular sizes; falls to a stacked layout with a floating
    /// swap at accessibility Dynamic Type sizes (§9.6). Both arrangements are
    /// `HStack`/`VStack`-composed, so they mirror under RTL for free. Handed
    /// to styles welded (ADR-0004 §9.2) — the fallback travels with the unit.
    private var routeFields: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                originPicker
                if showsSwapValue { swapControl("arrow.left.arrow.right") }
                destinationPicker
            }
            VStack(spacing: Theme.SpacingKey.xs.value) {
                originPicker
                destinationPicker
            }
            .overlay(alignment: .trailing) {
                if showsSwapValue {
                    swapControl("arrow.up.arrow.down")
                        .padding(.trailing, Theme.SpacingKey.lg.value)
                }
            }
        }
    }

    private var originPicker: some View {
        airportPicker(selection: $draft.origin,
                      placeholder: String(themeKitTravel: "From"),
                      icon: originIconName)
    }

    private var destinationPicker: some View {
        airportPicker(selection: $draft.destination,
                      placeholder: String(themeKitTravel: "To"),
                      icon: destinationIconName)
    }

    /// The embedded §9.4 picker — sheet presentation (FieldButton trigger),
    /// fed by the caller-owned dataset plumbed through `airports(…)` /
    /// `onAirportQuery(_:)`. The picker owns the query debounce; this card
    /// never spawns work of its own.
    private func airportPicker(selection: Binding<Airport?>, placeholder: String,
                               icon: String?) -> some View {
        var picker = AirportPicker(selection: selection, suggestions: suggestions)
            .presentation(.sheet)
            .placeholder(placeholder)
            .recent(recentAirports)
            .popular(popularAirports)
            .accent(accentColor)
        if let icon { picker = picker.triggerIcon(icon) }
        if let airportQueryAction { picker = picker.onQueryChange(airportQueryAction) }
        return picker
    }

    /// `draft.swapRoute()` behind the shared `SwapButton` atom, with a
    /// `MicroMotion`-gated half-turn. Rotation of a symmetric glyph is
    /// mirror-safe under RTL.
    private func swapControl(_ systemImage: String) -> some View {
        SwapButton(systemImage) {
            guard isEnabled, !isReadOnly else { return }
            withAnimation(motion) {
                draft.swapRoute()
                swapAngle += 180
            }
        }
        .rotationEffect(.degrees(swapAngle))
        .allowsHitTesting(!isReadOnly)
        .accessibilityLabel(String(themeKitTravel: "Swap origin and destination"))
    }

    // MARK: Dates (DateField ×1–2; return hidden for one-way / multi-city)

    private var dateFields: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            DateField(String(themeKitTravel: "Departure"), date: $draft.departureDate)
                .range(effectiveDateRange)
                .icon(departureIconName ?? "calendar")
            if showsReturnDate {
                DateField(String(themeKitTravel: "Return"), date: $draft.returnDate)
                    .range(returnDateRange)
                    .icon(departureIconName ?? "calendar")
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }

    // MARK: Passengers (FieldButton trigger → GuestSelector in a bottom sheet)

    /// `PassengerCount` ⇄ `GuestSelection` bridge — rooms pinned to 1 and
    /// hidden (`showsRooms(false)`), so only the three age bands round-trip.
    private var guestBinding: Binding<GuestSelection> {
        Binding(
            get: {
                GuestSelection(rooms: 1,
                               adults: draft.passengers.adults,
                               children: draft.passengers.children,
                               infants: draft.passengers.infants)
            },
            set: { selection in
                draft.passengers = PassengerCount(adults: selection.adults,
                                                  children: selection.children,
                                                  infants: selection.infants)
            }
        )
    }

    private var passengersTrigger: some View {
        FieldButton(passengerSummary) { isPassengerSheetPresented = true }
            .label(String(themeKitTravel: "Passengers"))
            .icon(passengersIconName ?? "person.2")
            .bottomSheet(isPresented: $isPassengerSheetPresented, detents: passengerDetents) {
                passengerSheet
            }
    }

    private var passengerSheet: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            Text(String(themeKitTravel: "Passengers"))
                .textStyle(.headingSm)
                .foregroundStyle(theme.text(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            GuestSelector(selection: guestBinding)
                .showsRooms(false)
            PrimaryButton(String(themeKitTravel: "Done")) { isPassengerSheetPresented = false }
                .fullWidth()
        }
    }

    /// "2 adults · 1 child" — the trigger echo of the current count.
    private var passengerSummary: String {
        let count = draft.passengers
        var parts = [count.adults == 1
            ? String(themeKitTravel: "1 adult")
            : String(themeKitTravel: "\(count.adults) adults")]
        if count.children > 0 {
            parts.append(count.children == 1
                ? String(themeKitTravel: "1 child")
                : String(themeKitTravel: "\(count.children) children"))
        }
        if count.infants > 0 {
            parts.append(count.infants == 1
                ? String(themeKitTravel: "1 infant")
                : String(themeKitTravel: "\(count.infants) infants"))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Cabin (CabinClassSelector)

    private var cabinSection: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Text(String(themeKitTravel: "Cabin"))
                .textStyle(.overline500)
                .foregroundStyle(theme.text(.textTertiary))
            // .chips (not the default .segmented): a search card is often narrow
            // (phone width, a sidebar column), where four equal segments can't fit
            // "Premium Economy" without wrapping the labels character-by-character.
            CabinClassSelector(selection: $draft.cabin)
                .accent(accentColor)
                .cabinClassSelectorStyle(.chips)
        }
    }

    // MARK: CTA

    /// The submit control, built in the three shapes styles arrange
    /// (`cta`/`heroCta`/`inlineCta`). A `.ctaLabel { }` slot replaces the
    /// button's look (caller-styled label inside a plain button) while the
    /// submit guard and completeness-driven `.disabled` wiring stay intact.
    @ViewBuilder
    private func ctaUnit(fullWidth: Bool, prominent: Bool) -> some View {
        if let ctaLabelContent {
            Button {
                guard !isReadOnly else { return }   // E1 — read-only never submits
                onSearch(draft)
            } label: {
                ctaLabelContent
                    .frame(maxWidth: fullWidth ? .infinity : nil)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isDraftComplete)
            .allowsHitTesting(!isReadOnly)
            .accessibilityAddTraits(.isButton)
        } else {
            PrimaryButton(ctaTitle) {
                guard !isReadOnly else { return }   // E1 — read-only never submits
                onSearch(draft)
            }
            .size(prominent ? .large : .medium)
            .fullWidth(fullWidth)
            .disabled(!isDraftComplete)
            .allowsHitTesting(!isReadOnly)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TripSearchCard {
    /// Data for the embedded ``AirportPicker`` sheets (same caller-owned model
    /// as §9.4): the live `suggestions` for the typed query, plus optional
    /// `recent` / `popular` sections shown before typing.
    func airports(suggestions: [Airport], recent: [Airport] = [], popular: [Airport] = []) -> Self {
        copy {
            $0.suggestions = suggestions
            $0.recentAirports = recent
            $0.popularAirports = popular
        }
    }

    /// Debounced query callback, plumbed into both embedded pickers — the
    /// caller runs its lookup and updates `suggestions`. The picker owns the
    /// debounce; this card never spawns work.
    func onAirportQuery(_ action: @escaping (String) -> Void) -> Self {
        copy { $0.airportQueryAction = action }
    }

    /// Selectable date window (past dates excluded by default). The return
    /// picker is additionally clamped to start at the chosen departure.
    func dateRange(_ range: ClosedRange<Date>) -> Self { copy { $0.explicitDateRange = range } }

    /// Show the inline ``CabinClassSelector`` (default true).
    func showsCabinPicker(_ on: Bool = true) -> Self { copy { $0.showsCabinPicker = on } }

    /// Show the ``TripTypeToggle`` row (default true). Hidden, the card keeps
    /// whatever `draft.tripType` the caller set.
    func showsTripType(_ on: Bool = true) -> Self { copy { $0.showsTripType = on } }

    /// CTA title (default "Search flights").
    func ctaTitle(_ text: String) -> Self { copy { $0.ctaTitleOverride = text } }

    /// Maps 1:1 onto the ``TripSearchCardStyle`` presets and, when called,
    /// wins over the environment style (source-behavior stability during
    /// migration — ADR-0004 §5).
    @available(*, deprecated, message: "Use .tripSearchCardStyle(_:) — e.g. .tripSearchCardStyle(.hero)")
    func variant(_ v: TripSearchVariant) -> Self {
        copy {
            switch v {
            case .card: $0.explicitStyle = AnyTripSearchCardStyle(CardTripSearchCardStyle())
            case .hero: $0.explicitStyle = AnyTripSearchCardStyle(HeroTripSearchCardStyle())
            case .compact: $0.explicitStyle = AnyTripSearchCardStyle(CompactTripSearchCardStyle())
            case .inlineBar: $0.explicitStyle = AnyTripSearchCardStyle(InlineBarTripSearchCardStyle())
            }
        }
    }

    /// Surface fill by background token, threaded into the active ``CardStyle``'s
    /// configuration (e.g. `.bgHero` under a hero header). When unset, the
    /// active ``TripSearchCardStyle`` picks its default (built-ins: `.bgWhite`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    /// Card elevation. When unset, the active ``TripSearchCardStyle`` picks
    /// (`.card`/`.compact`/`.inlineBar` → `.soft`, `.hero` and the expanded
    /// `.pill` → `.elevated`); an explicit call always wins.
    func elevation(_ e: CardElevation) -> Self { copy { $0.explicitElevation = e } }

    /// Semantic tint threaded through the composed pieces (trip-type pill,
    /// airport-picker chips, cabin selector, the `.pill` search disc). `nil`
    /// (default) keeps the stock hero chroma.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentColor = color } }

    /// Promo slot rendered under the CTA (campaign strip, fare notice…).
    /// Evaluated immediately at the call site.
    func promo<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.promoContent = AnyView(content()) }
    }

    /// Header slot above the editor (canonical `.header { }`) — e.g. a title
    /// or a route breadcrumb. Distinct from `.promo` (which sits under the CTA).
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.headerContent = AnyView(content()) }
    }

    /// Footer slot below the editor and the promo (canonical `.footer { }`) —
    /// e.g. a fare-rules note.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.footerContent = AnyView(content()) }
    }

    /// Replaces the CTA button's built-in label with caller content. The
    /// submit action, read-only guard and completeness-driven disabling are
    /// preserved; the caller owns the label's look entirely.
    func ctaLabel<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.ctaLabelContent = AnyView(content()) }
    }

    /// Editor density: `.regular` (default) or `.compact` — tighter stacks
    /// resolved from spacing tokens.
    func density(_ d: TripSearchDensity) -> Self { copy { $0.densityValue = d } }

    /// Overrides the field icons (SF Symbol names); `nil` keeps each field's
    /// stock symbol (origin/destination "airplane", departure "calendar",
    /// passengers "person.2"). The departure icon also styles the return field.
    func fieldIcons(origin: String? = nil, destination: String? = nil,
                    departure: String? = nil, passengers: String? = nil) -> Self {
        copy {
            $0.originIconName = origin
            $0.destinationIconName = destination
            $0.departureIconName = departure
            $0.passengersIconName = passengers
        }
    }

    /// Show the origin/destination swap affordance (default on).
    func showsSwap(_ on: Bool = true) -> Self { copy { $0.showsSwapValue = on } }

    /// Detents for the passengers bottom sheet (default `[.medium]`).
    func passengerSheetDetents(_ detents: [BottomSheetDetent]) -> Self {
        copy { $0.passengerDetents = detents.isEmpty ? [.medium] : detents }
    }

    /// Seeds the collapsing styles expanded (previews/snapshots only).
    internal func seedExpanded(_ on: Bool = true) -> Self {
        copy { $0._isExpanded = State(initialValue: on) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

private let previewAirports: [Airport] = [
    Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR"),
    Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB"),
    Airport(code: "JFK", name: "John F. Kennedy Airport", city: "New York", countryCode: "US"),
    Airport(code: "CDG", name: "Charles de Gaulle Airport", city: "Paris", countryCode: "FR"),
    Airport(code: "AMS", name: "Schiphol Airport", city: "Amsterdam", countryCode: "NL"),
]

private func previewDraft(roundTrip: Bool = true) -> TripSearchDraft {
    var draft = TripSearchDraft()
    draft.tripType = roundTrip ? .roundTrip : .oneWay
    draft.origin = previewAirports[0]
    draft.destination = previewAirports[1]
    draft.departureDate = Calendar.current.date(byAdding: .day, value: 7, to: .now)
    draft.returnDate = Calendar.current.date(byAdding: .day, value: 14, to: .now)
    draft.passengers = PassengerCount(adults: 2, children: 1)
    return draft
}

#Preview("Round trip (interactive)") {
    struct Demo: View {
        @State private var draft = previewDraft()
        @State private var results: [Airport] = []
        var body: some View {
            ScrollView {
                TripSearchCard(draft: $draft) { _ in }
                    .airports(suggestions: results,
                              recent: [previewAirports[2]],
                              popular: [previewAirports[0], previewAirports[3]])
                    .onAirportQuery { query in
                        results = query.isEmpty ? [] : previewAirports.filter {
                            $0.city.localizedCaseInsensitiveContains(query)
                                || $0.code.localizedCaseInsensitiveContains(query)
                        }
                    }
                    .padding()
            }
        }
    }
    return Demo()
}

#Preview("One-way · hero · compact · pill · accent") {
    struct Demo: View {
        @State private var oneWay = previewDraft(roundTrip: false)
        @State private var hero = previewDraft()
        @State private var compact = previewDraft()
        @State private var pill = previewDraft()
        @State private var empty = TripSearchDraft()
        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    // One-way: no return DateField.
                    TripSearchCard(draft: $oneWay) { _ in }
                    // Hero: larger padding + CTA, elevated by default.
                    TripSearchCard(draft: $hero) { _ in }
                        .accent(.success)
                        .tripSearchCardStyle(.hero)
                    // Compact: collapsed summary row.
                    TripSearchCard(draft: $compact) { _ in }
                        .tripSearchCardStyle(.compact)
                    // Pill: floating capsule that expands into the editor.
                    TripSearchCard(draft: $pill) { _ in }
                        .tripSearchCardStyle(.pill)
                    // Empty draft: placeholders + disabled CTA; trimmed axes.
                    TripSearchCard(draft: $empty) { _ in }
                        .showsTripType(false)
                        .showsCabinPicker(false)
                        .ctaTitle("Find fares")
                        .promo {
                            Text("Members save up to 20%").textStyle(.bodySm400)
                        }
                }
                .padding()
            }
        }
    }
    return Demo()
}

#Preview("Inline bar · slots · density · icons · detents") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State private var bar = previewDraft()
        @State private var dense = previewDraft(roundTrip: false)
        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    // Single-row bar for wide hosts (stacks when it can't fit).
                    TripSearchCard(draft: $bar) { _ in }
                        .showsSwap(false)
                        .header {
                            Text("Find your next flight").textStyle(.headingSm)
                        }
                        .tripSearchCardStyle(.inlineBar)

                    // Compact density + custom field icons + custom CTA label
                    // + footer + tall passenger sheet.
                    TripSearchCard(draft: $dense) { _ in }
                        .density(.compact)
                        .fieldIcons(origin: "airplane.departure",
                                    destination: "airplane.arrival",
                                    departure: "calendar.badge.clock",
                                    passengers: "person.3")
                        .passengerSheetDetents([.large])
                        .ctaLabel {
                            HStack(spacing: Theme.SpacingKey.xs.value) {
                                Icon(systemName: "magnifyingglass").size(.sm)
                                Text("Let's go").textStyle(.labelBase700)
                            }
                            .padding(Theme.SpacingKey.sm.value)
                        }
                        .footer {
                            Text("Prices include all taxes and fees.")
                                .textStyle(.bodySm400)
                        }
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
        @State private var draft = previewDraft()
        var body: some View {
            let dark = Theme()
            dark.loadTheme(named: Theme.defaultThemeName, dark: true)
            return ScrollView {
                TripSearchCard(draft: $draft) { _ in }
                    .accent(.info)
                    .padding()
            }
            .background(dark.background(.bgBase))
            .theme(dark)
        }
    }
    return Demo()
}
