//
//  Accordion.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum AccordionIndicator {
    case chevron
    case plusMinus
    case custom(expand: String, collapse: String)
}

/// Title text size of an accordion header. (Reference AccordionTitleSize.)
public enum AccordionTitleSize {
    case large, medium, small
    var textStyle: TextStyle {
        switch self {
        case .large: return .labelLg600
        case .medium: return .labelMd600
        case .small: return .labelBase600
        }
    }
}

/// Vertical padding of an accordion header row. (Reference AccordionPaddingSize.)
public enum AccordionPaddingSize {
    case `default`, small, large
    var value: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.xs.value    // 4
        case .default: return Theme.SpacingKey.sm.value  // 8
        case .large: return Theme.SpacingKey.md.value    // 16
        }
    }
}

/// Improved, token-bound rewrite of the reference AccordionView — a single
/// expandable row with a @ViewBuilder body instead of type-erased AnyView models.
public struct Accordion<Content: View>: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let content: () -> Content
    // Long-tail config — set via chainable modifiers, keeping the common call
    // site to `Accordion("Title", initiallyExpanded:) { … }`.
    private var leadingSystemImage: String? = nil
    private var subtitle: String? = nil
    private var number: Int? = nil
    private var indicator: AccordionIndicator = .chevron
    private var titleSize: AccordionTitleSize = .medium
    private var paddingSize: AccordionPaddingSize = .default
    private var truncateSubtitle: Bool = false
    private var showDivider: Bool = true

    /// Expansion state — uncontrolled (`initiallyExpanded:` seeds @State) or
    /// controlled (the caller's `isExpanded:` binding drives it), unified by
    /// `ControllableState` (ADR-4).
    @ControllableState private var expanded: Bool
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    public init(   // R1 — `initiallyExpanded` seeds @State, so it stays in the init
        _ title: String,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
        self._expanded = ControllableState(wrappedValue: initiallyExpanded)
    }

    public init(   // R1 — controlled expansion; the binding drives toggling
        _ title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
        self._expanded = ControllableState(wrappedValue: false, external: isExpanded)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Button {
                withAnimation(motion) { expanded.toggle() }
            } label: {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if let number {
                        Text(zeroPad2(number))
                            .textStyle(titleSize.textStyle)
                            .foregroundStyle(titleColor)
                            .monospacedDigit()
                    }
                    if let leadingSystemImage {
                        Icon(systemName: leadingSystemImage).size(.sm).colorOverride(titleColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .textStyle(titleSize.textStyle)
                            .foregroundStyle(titleColor)
                        if let subtitle {
                            Text(subtitle)
                                .textStyle(.bodySm400)
                                .foregroundStyle(theme.text(.textSecondary))
                                .lineLimit(truncateSubtitle && !expanded ? 1 : nil)
                        }
                    }
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    indicatorIcon
                }
                .padding(.vertical, paddingSize.value)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // State-aware for VoiceOver (Dropdown's disclosure convention).
            .accessibilityValue(expanded ? String(themeKit: "Expanded") : String(themeKit: "Collapsed"))

            if expanded {
                content()
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showDivider {
                DividerView().size(.small)
            }
        }
        // Value-based so controlled (binding-driven) changes animate too.
        .animation(motion, value: expanded)
    }

    @MainActor
    private var titleColor: Color {
        expanded ? theme.text(.textHero) : theme.text(.textPrimary)
    }

    @MainActor @ViewBuilder
    private var indicatorIcon: some View {
        switch indicator {
        case .chevron:
            Icon(systemName: "chevron.down").size(.sm).colorOverride(theme.text(.textTertiary))
                .rotationEffect(.degrees(expanded ? 180 : 0))
        case .plusMinus:
            Icon(systemName: expanded ? "minus" : "plus").size(.sm).colorOverride(theme.text(.textTertiary))
        case .custom(let expand, let collapse):
            Icon(systemName: expanded ? collapse : expand).size(.sm).colorOverride(theme.text(.textTertiary))
        }
    }
}

public extension Accordion {
    /// Leading SF Symbol shown before the title.
    func icon(_ systemImage: String?) -> Self { copy { $0.leadingSystemImage = systemImage } }
    /// A secondary line under the title.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    /// A leading two-digit number badge (e.g. a numbered FAQ / step).
    func number(_ value: Int?) -> Self { copy { $0.number = value } }
    /// Expand/collapse indicator glyph (chevron / plus-minus / custom).
    func indicator(_ indicator: AccordionIndicator) -> Self { copy { $0.indicator = indicator } }
    /// Title text size.
    func titleSize(_ size: AccordionTitleSize) -> Self { copy { $0.titleSize = size } }
    /// Header row vertical padding (default / small / large).
    func density(_ size: AccordionPaddingSize) -> Self { copy { $0.paddingSize = size } }
    /// Clamps the subtitle to one line while collapsed.
    func truncateSubtitle(_ on: Bool = true) -> Self { copy { $0.truncateSubtitle = on } }
    /// Whether to draw the bottom divider (default true).
    func divider(_ on: Bool) -> Self { copy { $0.showDivider = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var controlledOpen = false
    ScrollView {
        VStack(spacing: 8) {
            Accordion("What is your refund policy?", initiallyExpanded: true) {
                Text("You can request a refund within 14 days of purchase.")
            }
            Accordion("How do I contact support?") {
                Text("Email us at support@example.com.")
            }
            .icon("questionmark.circle")

            // Controlled expansion — the binding drives (and observes) the row.
            Accordion("Controlled from outside", isExpanded: $controlledOpen) {
                Text("This row's expansion is owned by the parent view.")
            }
            Button(controlledOpen ? "Collapse above" : "Expand above") {
                controlledOpen.toggle()
            }
        }
        .padding()
    }
}
