//
//  Accordion.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference AccordionView — a single
//  expandable row with a @ViewBuilder body instead of type-erased AnyView models.
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

public struct Accordion<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let number: Int?
    private let leadingSystemImage: String?
    private let indicator: AccordionIndicator
    private let titleSize: AccordionTitleSize
    private let paddingSize: AccordionPaddingSize
    private let truncateSubtitle: Bool
    private let showDivider: Bool
    private let content: () -> Content

    @State private var expanded: Bool

    public init(
        _ title: String,
        subtitle: String? = nil,
        number: Int? = nil,
        leadingSystemImage: String? = nil,
        indicator: AccordionIndicator = .chevron,
        titleSize: AccordionTitleSize = .medium,
        paddingSize: AccordionPaddingSize = .default,
        truncateSubtitle: Bool = false,
        initiallyExpanded: Bool = false,
        showDivider: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.number = number
        self.leadingSystemImage = leadingSystemImage
        self.indicator = indicator
        self.titleSize = titleSize
        self.paddingSize = paddingSize
        self.truncateSubtitle = truncateSubtitle
        self.showDivider = showDivider
        self.content = content
        self._expanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Button {
                withAnimation(Motion.base.animation) { expanded.toggle() }
            } label: {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if let number {
                        Text(String(format: "%02d", number))
                            .textStyle(titleSize.textStyle)
                            .foregroundStyle(titleColor)
                            .monospacedDigit()
                    }
                    if let leadingSystemImage {
                        Icon(systemName: leadingSystemImage, size: .sm, color: titleColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .textStyle(titleSize.textStyle)
                            .foregroundStyle(titleColor)
                        if let subtitle {
                            Text(subtitle)
                                .textStyle(.bodySm400)
                                .foregroundStyle(Theme.shared.text(.textSecondary))
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

            if expanded {
                content()
                    .textStyle(.bodyBase400)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showDivider {
                DividerView(size: .small)
            }
        }
    }

    private var titleColor: Color {
        expanded ? Theme.shared.text(.textHero) : Theme.shared.text(.textPrimary)
    }

    @ViewBuilder
    private var indicatorIcon: some View {
        switch indicator {
        case .chevron:
            Icon(systemName: "chevron.down", size: .sm, color: Theme.shared.text(.textTertiary))
                .rotationEffect(.degrees(expanded ? 180 : 0))
        case .plusMinus:
            Icon(systemName: expanded ? "minus" : "plus", size: .sm, color: Theme.shared.text(.textTertiary))
        case .custom(let expand, let collapse):
            Icon(systemName: expanded ? collapse : expand, size: .sm, color: Theme.shared.text(.textTertiary))
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 8) {
            Accordion("What is your refund policy?", initiallyExpanded: true) {
                Text("You can request a refund within 14 days of purchase.")
            }
            Accordion("How do I contact support?", leadingSystemImage: "questionmark.circle") {
                Text("Email us at support@example.com.")
            }
        }
        .padding()
    }
}
