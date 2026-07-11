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
//  The shell is drawn by the active **CardStyle**: the organism wraps its
//  content in the neutral `Card`, which routes `surface` / `elevation` through
//  `CardStyleConfiguration` — so `.cardStyle(_:)` set on the subtree re-chromes
//  this card exactly like every other card-shaped organism.
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

// MARK: - Variant

/// How ``TripSearchCard`` presents: the standard `.card`, a larger `.hero`
/// treatment for landing headers, or a `.compact` collapsed summary row that
/// expands into the full editor on tap.
public enum TripSearchVariant: Sendable { case card, hero, compact }

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
///     .variant(.hero)
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
    private var ctaTitle = String(themeKitTravel: "Search flights")
    private var variant: TripSearchVariant = .card
    private var surfaceKey: Theme.BackgroundColorKey = .bgWhite
    /// Explicit `.elevation(_:)` wins; otherwise `.hero` lifts to `.elevated`.
    private var explicitElevation: CardElevation?
    private var accentColor: SemanticColor?
    /// Promo slot under the CTA. Local erasure (ThemeKit's `SlotContent` is
    /// internal to that module); evaluated immediately at the modifier call
    /// site, so nothing escapes.
    private var promoContent: AnyView?

    /// UI-only state (house rule 1): sheet + compact-expansion + swap spin.
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

    private var effectiveElevation: CardElevation {
        explicitElevation ?? (variant == .hero ? .elevated : .soft)
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
        Card { cardBody }
            .contentPadding(variant == .hero ? .lg : .md)
            .elevation(effectiveElevation)
            .surface(surfaceKey)
            .animation(motion, value: isExpanded)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(themeKitTravel: "Flight search"))
    }

    @ViewBuilder
    private var cardBody: some View {
        if variant == .compact && !isExpanded {
            summaryRow
        } else {
            form
        }
    }

    // MARK: - Form (the full editor)

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if variant == .compact { collapseHeader }
            if showsTripType { tripTypeToggle }
            routeFields
            dateFields
            passengersTrigger
            if showsCabinPicker { cabinSection }
            cta
            if let promoContent { promoContent }
        }
        // `.oneWay` hides the return field; gated by `microAnimations` + Reduce Motion.
        .animation(motion, value: draft.tripType)
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
    /// `HStack`/`VStack`-composed, so they mirror under RTL for free.
    private var routeFields: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                originPicker
                swapControl("arrow.left.arrow.right")
                destinationPicker
            }
            VStack(spacing: Theme.SpacingKey.xs.value) {
                originPicker
                destinationPicker
            }
            .overlay(alignment: .trailing) {
                swapControl("arrow.up.arrow.down")
                    .padding(.trailing, Theme.SpacingKey.lg.value)
            }
        }
    }

    private var originPicker: some View {
        airportPicker(selection: $draft.origin, placeholder: String(themeKitTravel: "From"))
    }

    private var destinationPicker: some View {
        airportPicker(selection: $draft.destination, placeholder: String(themeKitTravel: "To"))
    }

    /// The embedded §9.4 picker — sheet presentation (FieldButton trigger),
    /// fed by the caller-owned dataset plumbed through `airports(…)` /
    /// `onAirportQuery(_:)`. The picker owns the query debounce; this card
    /// never spawns work of its own.
    private func airportPicker(selection: Binding<Airport?>, placeholder: String) -> some View {
        var picker = AirportPicker(selection: selection, suggestions: suggestions)
            .presentation(.sheet)
            .placeholder(placeholder)
            .recent(recentAirports)
            .popular(popularAirports)
            .accent(accentColor)
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
                .icon("calendar")
            if showsReturnDate {
                DateField(String(themeKitTravel: "Return"), date: $draft.returnDate)
                    .range(returnDateRange)
                    .icon("calendar")
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
            .icon("person.2")
            .bottomSheet(isPresented: $isPassengerSheetPresented, detents: [.medium]) {
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
                .variant(.chips)
                .accent(accentColor)
        }
    }

    // MARK: CTA

    private var cta: some View {
        PrimaryButton(ctaTitle) {
            guard !isReadOnly else { return }   // E1 — read-only never submits
            onSearch(draft)
        }
        .size(variant == .hero ? .large : .medium)
        .fullWidth()
        .disabled(!isDraftComplete)
        .allowsHitTesting(!isReadOnly)
    }

    // MARK: Compact (collapsed summary row → expands to the full editor)

    private var summaryRow: some View {
        Button {
            withAnimation(motion) { isExpanded = true }
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Icon(systemName: "magnifyingglass")
                    .size(.sm)
                    .color(theme.text(.textTertiary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(routeSummary)
                        .textStyle(.labelBase600)
                        .foregroundStyle(draft.origin == nil ? theme.text(.textTertiary) : theme.text(.textPrimary))
                    if !detailSummary.isEmpty {
                        Text(detailSummary)
                            .textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                }
                .lineLimit(1)
                Spacer(minLength: Theme.SpacingKey.xs.value)
                Icon(systemName: "chevron.down")
                    .size(.sm)
                    .color(theme.text(.textTertiary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(themeKitTravel: "Edit search"))
        .accessibilityValue("\(routeSummary), \(detailSummary)")
        .accessibilityAddTraits(.isButton)
    }

    private var collapseHeader: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(motion) { isExpanded = false }
            } label: {
                Icon(systemName: "chevron.up")
                    .size(.sm)
                    .color(theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(themeKitTravel: "Collapse search"))
        }
    }

    /// "Istanbul (IST) – London (LHR)" — an en dash, not an arrow, so the
    /// string stays direction-neutral under RTL.
    private var routeSummary: String {
        guard let origin = draft.origin, let destination = draft.destination else {
            return String(themeKitTravel: "Where to?")
        }
        return "\(AirportPicker.displayText(origin)) – \(AirportPicker.displayText(destination))"
    }

    /// "Jan 5 – Jan 12 · 2 travelers · Economy" — captured-locale formatting.
    private var detailSummary: String {
        var parts: [String] = []
        if let departure = draft.departureDate {
            var dates = format(departure)
            if showsReturnDate, let ret = draft.returnDate {
                dates += " – " + format(ret)
            }
            parts.append(dates)
        }
        let travelers = draft.passengers.total
        parts.append(travelers == 1
            ? String(themeKitTravel: "1 traveler")
            : String(themeKitTravel: "\(travelers) travelers"))
        parts.append(draft.cabin.label)
        return parts.joined(separator: " · ")
    }

    private func format(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
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
    func ctaTitle(_ text: String) -> Self { copy { $0.ctaTitle = text } }

    /// `.card` (default) · `.hero` (larger treatment for landing headers) ·
    /// `.compact` (collapsed summary row that expands on tap).
    func variant(_ v: TripSearchVariant) -> Self { copy { $0.variant = v } }

    /// Surface fill by background token, threaded into the active ``CardStyle``'s
    /// configuration (e.g. `.bgHero` under a hero header).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    /// Card elevation. Default `.soft` (`.elevated` for the `.hero` variant);
    /// an explicit call always wins.
    func elevation(_ e: CardElevation) -> Self { copy { $0.explicitElevation = e } }

    /// Semantic tint threaded through the composed pieces (trip-type pill,
    /// airport-picker chips, cabin selector). `nil` (default) keeps the stock
    /// hero chroma.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentColor = color } }

    /// Promo slot rendered under the CTA (campaign strip, fare notice…).
    /// Evaluated immediately at the call site.
    func promo<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.promoContent = AnyView(content()) }
    }

    /// Seeds the compact variant expanded (previews/snapshots only).
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

#Preview("One-way · hero · compact · accent") {
    struct Demo: View {
        @State private var oneWay = previewDraft(roundTrip: false)
        @State private var hero = previewDraft()
        @State private var compact = previewDraft()
        @State private var empty = TripSearchDraft()
        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    // One-way: no return DateField.
                    TripSearchCard(draft: $oneWay) { _ in }
                    // Hero: larger padding + CTA, elevated by default.
                    TripSearchCard(draft: $hero) { _ in }
                        .variant(.hero)
                        .accent(.success)
                    // Compact: collapsed summary row.
                    TripSearchCard(draft: $compact) { _ in }
                        .variant(.compact)
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
