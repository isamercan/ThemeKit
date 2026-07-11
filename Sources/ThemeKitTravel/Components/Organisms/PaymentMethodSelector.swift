//
//  PaymentMethodSelector.swift
//  ThemeKitTravel
//
//  Edition organism (F1.3 · ADR §9.3). Choose how to pay — card / wallet /
//  transfer rows (`.list`, the default) or tiles (`.grid`), with an optional
//  inline `InstallmentPicker` under the selected `.card` option. Composes
//  ThemeKit's neutral `ListRow` anatomy, `RadioButton`, `Badge` and
//  `InstallmentPicker` — nothing is re-implemented here.
//
//  State follows ADR-F4: controlled-first (`selection: Binding<String?>`) plus
//  an uncontrolled preview convenience (`initiallySelected:`), both funneled
//  through `ControllableState`. Currency for the installment amounts is NOT a
//  parameter — it resolves inside `InstallmentPicker` via the §10 chain
//  (`\.formatDefaults` > locale currency > "USD").
//
//  ```swift
//  PaymentMethodSelector(options, selection: $method)
//      .installments([1, 3, 6, 9], selection: $months, total: fareTotal)
//      .badge("No fee", for: "transfer")
//  ```
//

import SwiftUI
import ThemeKit

/// Layout archetype of a ``PaymentMethodSelector``: radio rows or tiles.
public enum PaymentMethodVariant: Sendable { case list, grid }

/// A payment-method chooser — radio-semantic rows (or tiles) over
/// ``PaymentMethodOption`` values, with an optional inline instalment picker
/// under the selected card option.
public struct PaymentMethodSelector: View {
    @Environment(\.theme) private var theme
    @Environment(\.isReadOnly) private var isReadOnly
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let options: [PaymentMethodOption]
    /// Selected option id — controlled or uncontrolled per init (ADR-F4).
    @ControllableState private var selection: String?

    // Config — mutated only through the modifiers below (R2).
    private var variantValue: PaymentMethodVariant = .list
    private var installmentMonths: [Int]?
    private var installmentSelection: Binding<Int>?
    private var installmentTotal: Decimal?
    private var badges: [String: String] = [:]
    private var disabledIDs: Set<String> = []
    private var accent: SemanticColor?
    private var footerSlot: AnyView?

    /// R1 — options + controlled selection (option id). The binding is the
    /// change channel; observe with `.onChange(of:)` at the call site.
    public init(_ options: [PaymentMethodOption], selection: Binding<String?>) {
        self.options = options
        self._selection = ControllableState(wrappedValue: nil, external: selection)
    }

    /// Uncontrolled convenience (browse/preview contexts); the component owns
    /// the selection and it reads back only visually.
    public init(_ options: [PaymentMethodOption], initiallySelected: String? = nil) {
        self.options = options
        self._selection = ControllableState(wrappedValue: initiallySelected)
    }

    private var motion: Animation? {
        MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion)
    }
    private var accentBase: Color { (accent ?? .primary).base }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            switch variantValue {
            case .list: listBody
            case .grid: gridBody
            }
            if let footerSlot { footerSlot }
        }
        .animation(motion, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(themeKitTravel: "Payment method, \(options.count) options"))
    }

    // MARK: List variant — ListRow anatomy with radio semantics

    @MainActor
    private var listBody: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                row(option)
                if showsInstallments(under: option) {
                    inlineInstallments
                        .padding(.bottom, Theme.SpacingKey.sm.value)
                }
                if index < options.count - 1 {
                    DividerView().size(.small)
                }
            }
        }
    }

    @MainActor
    private func row(_ option: PaymentMethodOption) -> some View {
        let isOn = selection == option.id
        return ListRow(option.title) { select(option.id) }
            .subtitle(option.subtitle)
            .leading {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    RadioButton(isSelected: isSelectedBinding(option.id)).accent(accent)
                    Icon(systemName: option.systemImage)
                        .size(.sm)
                        .color(isOn ? accentBase : theme.text(.textSecondary))
                }
            }
            .badge(badges[option.id])
            .selected(isOn)
            .trailing(ListRowTrailing.none)
            .disabled(disabledIDs.contains(option.id))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Grid variant — selection tiles (vertical fallback at a11y sizes)

    @MainActor
    @ViewBuilder
    private var gridBody: some View {
        let gap = Theme.SpacingKey.sm.value
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: gap) { ForEach(options) { tile($0) } }
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: gap), GridItem(.flexible(), spacing: gap)],
                spacing: gap
            ) {
                ForEach(options) { tile($0) }
            }
        }
        if options.contains(where: { showsInstallments(under: $0) }) {
            inlineInstallments
        }
    }

    @MainActor
    private func tile(_ option: PaymentMethodOption) -> some View {
        let isOn = selection == option.id
        let isDisabled = disabledIDs.contains(option.id)
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
        return Button { select(option.id) } label: {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                Icon(systemName: option.systemImage)
                    .size(.md)
                    .color(isDisabled ? theme.text(.textDisabled) : (isOn ? accentBase : theme.text(.textSecondary)))
                Text(option.title)
                    .textStyle(.labelSm600)
                    .foregroundStyle(isDisabled ? theme.text(.textDisabled) : theme.text(.textPrimary))
                    .multilineTextAlignment(.center)
                if let subtitle = option.subtitle {
                    Text(subtitle)
                        .textStyle(.bodySm400)
                        .foregroundStyle(isDisabled ? theme.text(.textDisabled) : theme.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .padding(Theme.SpacingKey.md.value)
            .background(isOn ? (accent ?? .primary).bg : theme.background(.bgBase), in: shape)
            .overlay(shape.stroke(isOn ? accentBase : theme.border(.borderPrimary), lineWidth: isOn ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                if let badgeText = badges[option.id] {
                    Badge(badgeText).badgeStyle(.info).variant(.soft).size(.small)
                        .padding(Theme.SpacingKey.xs.value)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .allowsHitTesting(!isReadOnly)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Installments (composes the existing InstallmentPicker)

    /// Whether the inline instalment picker belongs under this option: the
    /// modifier is configured, the option is the current selection, and it is
    /// a `.card` method.
    @MainActor
    private func showsInstallments(under option: PaymentMethodOption) -> Bool {
        installmentMonths?.isEmpty == false
            && installmentSelection != nil
            && installmentTotal != nil
            && option.kind == .card
            && option.id == selection
    }

    @MainActor
    @ViewBuilder
    private var inlineInstallments: some View {
        if let months = installmentMonths, let picked = installmentSelection, let total = installmentTotal {
            // Currency deliberately not set: InstallmentPicker resolves it via
            // the §10 chain (`\.formatDefaults` > locale currency > "USD").
            InstallmentPicker(months.map { count in
                InstallmentOption(
                    count: count,
                    total: total,
                    monthly: count > 1 ? total / Decimal(count) : nil
                )
            }, selection: picked)
            .accent(accent)
            .padding(.leading, Theme.SpacingKey.lg.value)
            .transition(.opacity)
        }
    }

    // MARK: Selection plumbing

    @MainActor
    private func select(_ id: String) {
        guard !isReadOnly else { return }   // E1 — read-only blocks mutation, not focus
        selection = id
    }

    /// Radio-style binding for one option: setting `true` selects it; a
    /// payment method can't be deselected by tapping its own radio.
    @MainActor
    private func isSelectedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selection == id },
            set: { if $0 { select(id) } }
        )
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PaymentMethodSelector {
    /// Layout archetype: `.list` radio rows (default) or `.grid` tiles.
    func variant(_ v: PaymentMethodVariant) -> Self { copy { $0.variantValue = v } }

    /// Instalment plans shown inline under the selected `.card` option.
    /// `total` is required (§1.4 rev. 5) — per-month amounts derive from it
    /// (`total / months`); `selection` is the chosen instalment count, a
    /// separate outcome owned by the caller. Currency resolves via the
    /// environment chain (`\.formatDefaults` > locale > "USD").
    func installments(_ months: [Int], selection: Binding<Int>, total: Decimal) -> Self {
        copy {
            $0.installmentMonths = months
            $0.installmentSelection = selection
            $0.installmentTotal = total
        }
    }

    /// Per-option badge, e.g. "No fee" on a transfer method. Pass `nil` to clear.
    func badge(_ text: String?, for optionID: String) -> Self {
        copy { $0.badges[optionID] = text }
    }

    /// Options rendered disabled and excluded from selection.
    func disabledMethods(_ ids: Set<String>) -> Self { copy { $0.disabledIDs = ids } }

    /// Semantic tint for the radio / selected chrome / instalment rows;
    /// `nil` (default) uses the primary triad.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Bottom-aligned accessory area (canonical `.footer { }` slot), e.g. a
    /// security note or fee disclaimer.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.footerSlot = AnyView(content()) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

#Preview("List · installments · badge · disabled") {
    struct Demo: View {
        @State private var method: String? = "card"
        @State private var months = 3
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                    PaymentMethodSelector([
                        .init(id: "card", kind: .card, title: "Credit / debit card"),
                        .init(id: "wallet", kind: .wallet, title: "Digital wallet", subtitle: "Pay in one tap"),
                        .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
                    ], selection: $method)
                        .installments([1, 3, 6, 9], selection: $months, total: 1_240)
                        .badge("No fee", for: "transfer")
                        .disabledMethods(["wallet"])
                        .footer {
                            Text("All payments are encrypted.")
                                .textStyle(.bodySm400)
                        }

                    ListSectionHeader("Uncontrolled · accent · read-only")
                    PaymentMethodSelector([
                        .init(id: "card", kind: .card, title: "Credit / debit card"),
                        .init(id: "transfer", kind: .transfer, title: "Bank transfer"),
                    ], initiallySelected: "transfer")
                        .accent(.success)
                        .readOnly()
                }
                .padding()
            }
        }
    }
    return Demo()
}

#Preview("Grid · dark") {
    struct Demo: View {
        @State private var method: String? = "wallet"
        var body: some View {
            let dark = Theme()
            dark.loadTheme(named: Theme.defaultThemeName, dark: true)
            return VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
                PaymentMethodSelector([
                    .init(id: "card", kind: .card, title: "Card"),
                    .init(id: "wallet", kind: .wallet, title: "Wallet", subtitle: "One tap"),
                    .init(id: "transfer", kind: .transfer, title: "Transfer"),
                    .init(id: "card2", kind: .card, title: "Corporate card"),
                ], selection: $method)
                    .variant(.grid)
                    .badge("New", for: "wallet")
            }
            .padding()
            .background(dark.background(.bgBase))
            .theme(dark)
        }
    }
    return Demo()
}
