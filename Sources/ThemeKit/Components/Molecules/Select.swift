//
//  Select.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Single-select dropdown. Two modes: a native `Menu` (with grouped Sections)
//  or a searchable inline panel (`.searchable()`) with a search field +
//  section headers — the reference Select's sectioned + searchable picker.
//

import SwiftUI

/// A single-select dropdown — a native `Menu` by default, or a searchable inline
/// panel with section headers when `.searchable()` is on.
///
/// ```swift
/// Select("City", options: cities, selection: $city) { $0.name }
///     .searchable()
/// ```
public struct Select<Option: Hashable>: View {
    @Environment(\.theme) private var theme

    public struct Section {
        public let title: String?
        public let options: [Option]
        public init(_ title: String? = nil, _ options: [Option]) { self.title = title; self.options = options }
    }

    private let label: String
    private let sections: [Section]
    @Binding private var selection: Option?
    private let optionTitle: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var placeholderOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var placeholder: String { placeholderOverride ?? String(themeKit: "Select") }
    /// Set only by the `.clearable(_:)` modifier, so the subtree
    /// `FieldDefaults.clearable` can fill the default without overriding an
    /// explicit per-field choice (F5): `explicitClearable ?? fieldDefaults.clearable ?? false`.
    private var explicitClearable: Bool?
    private var searchable: Bool = false
    private var size: TextInputSize = .medium
    private var infoMessages: [InfoMessage] = []
    private var isLoading: Bool = false
    private var isOptionEnabled: ((Option) -> Bool)? = nil
    private var describeOption: ((Option) -> String?)? = nil
    private var leadingContent: ((Option) -> AnyView)? = nil
    /// Max height of the searchable dropdown before it scrolls (Ant `listHeight`,
    /// default 256). `nil` uses the 256pt default.
    private var listHeightOverride: CGFloat?
    /// Custom match predicate (Ant `filterOption`) — `nil` keeps the built-in
    /// case-insensitive `contains`. Return `true` to keep the option for `query`.
    private var filterPredicate: ((_ query: String, _ option: Option) -> Bool)?
    /// Custom ordering for the filtered rows (Ant `filterSort`); `nil` keeps order.
    private var filterSort: ((Option, Option) -> Bool)?
    private var accessibilityID: String? = nil
    /// Marks the field as required: asterisk after the label + ", required"
    /// appended to the accessibility label (E2, HeroUI `isRequired`).
    private var isRequired = false
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    @Environment(\.isReadOnly) private var isReadOnly // E1 — set by `.readOnly(_:)`
    @Environment(\.fieldDefaults) private var fieldDefaults

    /// Legacy chrome hook — honored only when a custom style was injected with
    /// the (deprecated) `.selectStyle(_:)`. Otherwise chrome comes from `\.fieldStyle`.
    @Environment(\.selectStyle) private var selectStyle
    /// The shared form-field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle

    /// Open state of the searchable panel (R1 — bindings belong in `init`) —
    /// uncontrolled (internal `@State`) or controlled (the caller's
    /// `isExpanded:` binding drives it), unified by `ControllableState`
    /// (ADR-4). Native-`Menu` mode manages its own presentation (SwiftUI
    /// exposes no `isPresented` for `Menu`), so the binding is honored only
    /// together with `.searchable()`.
    @ControllableState private var open: Bool
    @State private var query = ""

    public init(   // R1
        _ label: String,
        options: [Option],
        selection: Binding<Option?>,
        isExpanded: Binding<Bool>? = nil,
        optionTitle: @escaping (Option) -> String
    ) {
        self.init(label, sections: [Section(nil, options)], selection: selection, isExpanded: isExpanded, optionTitle: optionTitle)
    }

    public init(   // R1
        _ label: String,
        sections: [Section],
        selection: Binding<Option?>,
        isExpanded: Binding<Bool>? = nil,
        optionTitle: @escaping (Option) -> String
    ) {
        self.label = label
        self.sections = sections
        self._selection = selection
        self._open = ControllableState(wrappedValue: false, external: isExpanded)
        self.optionTitle = optionTitle
    }

    private var hasValue: Bool { selection != nil }
    /// Explicit `.clearable(_:)` → subtree `FieldDefaults.clearable` → off (F5).
    private var effectiveClearable: Bool { explicitClearable ?? fieldDefaults.clearable ?? false }
    private var showsClear: Bool { effectiveClearable && hasValue && isEnabled && !isReadOnly && !isLoading }
    /// Whether `.required()` renders its asterisk (`FieldDefaults.requiredIndicator`;
    /// the accessibility ", required" suffix is unaffected).
    private var showsRequiredIndicator: Bool { fieldDefaults.requiredIndicator ?? true }
    private func optionEnabled(_ option: Option) -> Bool { isOptionEnabled?(option) ?? true }
    private var hasAnyResults: Bool { sections.contains { !filtered($0.options).isEmpty } }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            ZStack(alignment: .trailing) {
                if searchable {
                    Button { if isEnabled && !isReadOnly { open.toggle() } } label: { field }
                        .buttonStyle(.plain)
                        .disabled(!isEnabled)
                } else {
                    Menu { menuContent } label: { field }
                        .disabled(!isEnabled)
                }
                clearButton
            }
            // E1 — read-only keeps the normal (non-dimmed) chrome + value +
            // VoiceOver value, but the menu / panel can't be opened and the
            // clear button is hidden. Deliberately NOT `.disabled`, which dims.
            .allowsHitTesting(!isReadOnly)
            .a11y(A11yElement.Select.trigger, in: accessibilityID)
            .accessibilityLabel(isRequired ? label + ", " + String(themeKit: "required") : label)
            .accessibilityValue(selection.map(optionTitle) ?? "")

            if searchable && open && !isReadOnly { panel }   // E1 — panel closes under read-only
            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
        .animation(Motion.fast.animation, value: open)
    }

    // MARK: Trigger field

    @MainActor
    private var fieldContent: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ZStack(alignment: .leading) {
                HStack(spacing: 4) {   // matches the `InputLabel` atom's asterisk gap
                    Text(label)
                        .foregroundStyle(hasValue ? theme.text(.textHero) : theme.text(.textTertiary))
                    if isRequired && showsRequiredIndicator {
                        // Same treatment as `InputLabel.required()` — error-token asterisk.
                        Text(verbatim: "*")
                            .foregroundStyle(theme.foreground(.systemcolorsFgError))
                            .accessibilityHidden(true)   // spoken via the trigger's label suffix
                    }
                }
                .textStyle(hasValue ? .labelSm600 : .bodyBase400)
                .offset(y: hasValue ? -11 : 0)
                if let selection {
                    Text(optionTitle(selection))
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textPrimary))
                        .offset(y: 9)
                }
            }
            Spacer(minLength: 0)
            if isLoading {
                Spinner().size(IconSize.sm.value).lineWidth(2)
            } else {
                Icon(systemName: open ? "chevron.up" : "chevron.down")
                    .size(.sm)
                    .color(showsClear ? .clear : theme.text(.textTertiary))
                    .accessibilityHidden(true)   // decorative — the trigger carries the label + value
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .scaledControlHeight(size.height)
        .frame(maxWidth: .infinity)
    }

    /// The trigger field — content composed here, chrome supplied by a style.
    ///
    /// When the environment still holds the *default* `SelectStyle` (nobody called
    /// the deprecated `.selectStyle(_:)`), chrome is delegated to the shared
    /// ``FieldStyle`` via `\.fieldStyle`: the open state maps to `isFocused`, and
    /// `size` maps 1:1 (Select's size axis is already a `TextInputSize`). If a
    /// custom `SelectStyle` *was* injected, the legacy path renders unchanged.
    @MainActor @ViewBuilder
    private var field: some View {
        if selectStyle.isDefault {
            fieldStyle.makeBody(configuration: FieldStyleConfiguration(
                content: AnyView(fieldContent),
                isFocused: open,
                isEnabled: isEnabled,
                hasError: infoMessages.dominantKind == .error,
                hasWarning: infoMessages.dominantKind == .warning,
                size: size
            ))
        } else {
            selectStyle.makeBody(configuration: SelectStyleConfiguration(
                content: AnyView(fieldContent),
                isOpen: open,
                isEnabled: isEnabled,
                hasError: infoMessages.dominantKind == .error,
                hasWarning: infoMessages.dominantKind == .warning
            ))
        }
    }

    @ViewBuilder
    private var clearButton: some View {
        if showsClear {
            Button { selection = nil } label: {
                Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .padding(.trailing, Theme.SpacingKey.md.value)
            .accessibilityLabel(String(themeKit: "Clear selection"))
        }
    }

    // MARK: Menu mode

    @ViewBuilder
    private var menuContent: some View {
        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
            if let title = section.title {
                SwiftUI.Section(title) { rows(section.options) }
            } else {
                rows(section.options)
            }
        }
    }

    /// Native menu rows. A second `Text` in a menu button's label renders as the
    /// system subtitle line — that's how `optionDescription` reaches this mode.
    /// The system styles menu rows itself (theme tokens can't apply inside a
    /// native `Menu`); `optionLeading` views are likewise stripped by the menu,
    /// so custom leading content appears only in the searchable panel.
    @ViewBuilder
    private func rows(_ options: [Option]) -> some View {
        ForEach(options, id: \.self) { option in
            Button {
                selection = option
            } label: {
                Text(optionTitle(option))
                if let description = describeOption?(option) {
                    Text(description)
                }
                if selection == option {
                    Image(systemName: "checkmark")
                }
            }
            .disabled(!optionEnabled(option))
        }
    }

    // MARK: Searchable panel

    private func filtered(_ options: [Option]) -> [Option] {
        var result = options
        if !query.isEmpty {
            if let filterPredicate {
                result = result.filter { filterPredicate(query, $0) }
            } else {
                result = result.filter { optionTitle($0).localizedCaseInsensitiveContains(query) }
            }
        }
        if let filterSort { result.sort(by: filterSort) }
        return result
    }

    /// Dropdown height cap before scrolling (Ant `listHeight`; default 256).
    private var effectiveListHeight: CGFloat { listHeightOverride ?? 256 }
    /// Rough count of visible rows (option rows + section headers) — decides
    /// whether the results need the capped scroll container.
    private var visibleRowCount: Int {
        sections.reduce(0) { acc, section in
            let opts = filtered(section.options)
            return acc + (opts.isEmpty ? 0 : opts.count + (section.title != nil ? 1 : 0))
        }
    }
    /// Approx results height at ~44pt/row — only used to pick scroll-vs-plain.
    private var estimatedResultsHeight: CGFloat { CGFloat(visibleRowCount) * 44 }

    @ViewBuilder
    private func panelMessage(spinner: Bool, _ text: String) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if spinner { Spinner().size(IconSize.sm.value).lineWidth(2) }
            Text(text).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
            Spacer()
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    /// The scrollable option rows (section headers + option buttons), extracted
    /// so the panel can wrap them in a capped `ScrollView` when they overflow.
    @MainActor @ViewBuilder
    private var panelResults: some View {
        VStack(spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                let opts = filtered(section.options)
                if !opts.isEmpty {
                    if let title = section.title {
                        Text(title).textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.SpacingKey.md.value).padding(.vertical, Theme.SpacingKey.xs.value)
                    }
                    ForEach(opts, id: \.self) { option in
                        let enabled = optionEnabled(option)
                        Button { selection = option; open = false; query = "" } label: {
                            HStack(spacing: Theme.SpacingKey.sm.value) {
                                if let leadingContent { leadingContent(option) }
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(optionTitle(option)).textStyle(.bodyBase400).foregroundStyle(theme.text(.textPrimary))
                                    if let description = describeOption?(option) {
                                        Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                                    }
                                }
                                Spacer()
                                if selection == option {
                                    Icon(systemName: "checkmark").size(.sm).color(theme.foreground(.fgHero))
                                }
                            }
                            .padding(.horizontal, Theme.SpacingKey.md.value).padding(.vertical, Theme.SpacingKey.sm.value)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(RowPressStyle())
                        .disabled(!enabled)
                        .opacity(enabled ? 1 : 0.4)
                        .accessibilityAddTraits(selection == option ? .isSelected : [])
                    }
                }
            }
        }
    }

    @MainActor
    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Icon(systemName: "magnifyingglass").size(.sm).color(theme.text(.textTertiary))
                TextField(String(themeKit: "Search"), text: $query).textStyle(.bodyBase400).tint(theme.foreground(.fgHero))
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .scaledControlHeight(44)
            DividerView().size(.small)

            if isLoading {
                panelMessage(spinner: true, String(themeKit: "Searching…"))
            } else if !hasAnyResults {
                panelMessage(spinner: false, String(themeKit: "No results"))
            } else if estimatedResultsHeight > effectiveListHeight {
                // Long lists scroll within the `listHeight` cap (Ant `listHeight`).
                ScrollView(showsIndicators: true) { panelResults }
                    .frame(height: effectiveListHeight)
            } else {
                panelResults   // short lists size to content — no wasted space
            }
        }
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .stroke(theme.border(.borderPrimary), lineWidth: 1)
        )
        .themeShadow(.soft)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Select {
    /// Placeholder shown while no option is selected.
    func placeholder(_ text: String) -> Self { copy { $0.placeholderOverride = text } }

    /// Show a trailing clear button when an option is selected. An explicit
    /// call wins over the subtree `FieldDefaults.clearable` default (F5).
    func clearable(_ on: Bool = true) -> Self { copy { $0.explicitClearable = on } }

    /// Use the searchable inline panel instead of the native menu.
    func searchable(_ on: Bool = true) -> Self { copy { $0.searchable = on } }

    /// Max height of the searchable dropdown before it scrolls (Ant `listHeight`,
    /// default 256pt). Short lists still size to their content.
    func listHeight(_ height: CGFloat) -> Self { copy { $0.listHeightOverride = height } }

    /// Custom match predicate for the searchable panel (Ant `filterOption`):
    /// `keep(query, option)` returns whether to keep the option. `nil` (default)
    /// keeps the built-in case-insensitive title `contains`. Pass `{ _, _ in true }`
    /// to disable client filtering (drive results from a server via `.loading`).
    func filter(_ keep: ((_ query: String, _ option: Option) -> Bool)?) -> Self { copy { $0.filterPredicate = keep } }

    /// Order the filtered rows (Ant `filterSort`); `nil` keeps declaration order.
    func filterSort(_ areInIncreasingOrder: ((Option, Option) -> Bool)?) -> Self { copy { $0.filterSort = areInIncreasingOrder } }

    /// Control height of the trigger field (small / medium / large).
    func size(_ size: TextInputSize) -> Self { copy { $0.size = size } }

    /// Marks the field as required: renders an error-token asterisk after the
    /// floating label (the `InputLabel` treatment, honoring the subtree
    /// `FieldDefaults.requiredIndicator`) and appends ", required" to the
    /// trigger's accessibility label (E2, HeroUI `isRequired`).
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Validation / info messages rendered under the field (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Shows a loading spinner in place of the chevron (async option fetch).
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Per-option enable predicate; disabled rows are shown greyed and unselectable.
    func optionEnabled(_ predicate: ((Option) -> Bool)?) -> Self { copy { $0.isOptionEnabled = predicate } }

    /// Second line rendered under each option title (HeroUI `Select.ItemDescription`).
    /// Return `nil` for options without one. In the searchable panel it renders
    /// `.bodySm400` in the secondary text token; in native-`Menu` mode it becomes
    /// the system-styled menu subtitle (tokens can't apply inside a native menu).
    func optionDescription(_ text: @escaping (Option) -> String?) -> Self { copy { $0.describeOption = text } }

    /// Custom leading content rendered before each option title in the
    /// **searchable panel** rows (e.g. a `StatusDot` or `Icon`). Native `Menu`
    /// rows strip custom views, so this has no effect without `.searchable()`.
    func optionLeading<V: View>(@ViewBuilder _ content: @escaping (Option) -> V) -> Self {
        copy { $0.leadingContent = { AnyView(content($0)) } }
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

#Preview {
    struct Demo: View {
        @State var city: String?
        @State var plan: String?
        var body: some View {
            let planDetails = [
                "Basic": "Essential features for personal use",
                "Pro": "Advanced tools for power users",
                "Team": "Collaboration for organizations",
            ]
            PreviewMatrix("Select") {
                PreviewCase("Clearable") {
                    Select("City", options: ["Istanbul", "Ankara", "Izmir"], selection: $city) { $0 }
                        .clearable()
                }
                PreviewCase("Searchable sections") {
                    Select("Searchable", sections: [.init("Marmara", ["Istanbul", "Bursa"]), .init("Aegean", ["Izmir", "Aydin"])],
                           selection: $city) { $0 }
                        .searchable()
                }
                // Native-menu subtitles via optionDescription.
                PreviewCase("Menu subtitles") {
                    Select("Plan (menu)", options: ["Basic", "Pro", "Team"], selection: $plan) { $0 }
                        .optionDescription { planDetails[$0] }
                }
                // Panel rows with descriptions + custom leading content,
                // driven by a controlled isExpanded binding.
                PreviewCase("Open panel + leading content") {
                    Select("Plan (panel)", options: ["Basic", "Pro", "Team"], selection: $plan, isExpanded: .constant(true)) { $0 }
                        .searchable()
                        .optionDescription { planDetails[$0] }
                        .optionLeading { StatusDot($0 == "Pro" ? .online : .neutral) }
                }
                // Chrome via the shared FieldStyle axis.
                PreviewCase("Underlined") {
                    Select("Underlined", options: ["Istanbul", "Ankara", "Izmir"], selection: $city) { $0 }
                        .fieldStyle(.underlined)
                }
                // Long list scrolls within a 180pt `listHeight` cap (Ant `listHeight`),
                // sorted A→Z via `filterSort`.
                PreviewCase("listHeight + filterSort") {
                    Select("Country", options: ["Turkey", "Germany", "France", "Spain", "Italy",
                                                "Poland", "Sweden", "Norway", "Greece", "Portugal"],
                           selection: $city, isExpanded: .constant(true)) { $0 }
                        .searchable()
                        .listHeight(180)
                        .filterSort(<)
                }
                // Required indicator (E2) — asterisk + ", required" for VoiceOver.
                PreviewCase("Required (E2)") {
                    Select("Departure city", options: ["Istanbul", "Ankara", "Izmir"], selection: $city) { $0 }
                        .required()
                }
                // Read-only (E1): normal chrome + value, menu / clear blocked.
                PreviewCase("Read-only (E1)") {
                    Select("Cabin", options: ["Economy", "Business"], selection: .constant("Economy")) { $0 }
                        .clearable()
                        .readOnly()
                }
            }
        }
    }
    return Demo()
}
