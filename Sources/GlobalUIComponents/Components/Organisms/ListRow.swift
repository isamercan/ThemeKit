//
//  ListRow.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  A flexible list row that consolidates the reference ListItem family
//  (Default / Chevron / Checkbox / Radio / Menu / Quick-action) into one
//  token-bound view. Leading: SF Symbol, remote image, number badge or a radio
//  selector. Trailing: chevron / value / toggle / checkmark / bound checkbox /
//  inline button / price block / status text. Plus a per-row meta line (rating,
//  sentiment, comment count), an active-selected background and an info button.
//

import SwiftUI

/// Structured trailing price: a single total, or an "each / unit" + total stack.
public struct ListRowPrice {
    let total: String
    let each: String?
    let unit: String
    public init(total: String, each: String? = nil, unit: String = "/ ay") {
        self.total = total
        self.each = each
        self.unit = unit
    }
}

/// Optional per-row metadata line (rating number + star, a sentiment word, a
/// comment-count). Mirrors the reference rich list-item rows.
public struct ListRowMeta {
    let rating: Double?
    let ratingLabel: String?
    let sentiment: String?
    let commentLabel: String?
    public init(rating: Double? = nil, ratingLabel: String? = nil, sentiment: String? = nil, commentLabel: String? = nil) {
        self.rating = rating
        self.ratingLabel = ratingLabel
        self.sentiment = sentiment
        self.commentLabel = commentLabel
    }
}

public enum ListRowTrailing {
    case none
    case chevron
    case value(String)
    case toggle(Binding<Bool>)
    case checkmark(Bool)
    /// A bound checkbox (checkbox list item).
    case checkbox(Binding<Bool>)
    /// An inline link button with its own action.
    case button(String, action: () -> Void)
    /// A structured price block.
    case price(ListRowPrice)
    /// Status text in success color, with an optional leading icon.
    case status(String, systemImage: String?)
}

/// Title weight/size tier of a list row. (Reference ListItem `.bold/.regular/.small`.)
public enum ListRowSize {
    case small, regular, bold
    var titleStyle: TextStyle {
        switch self {
        case .small: return .labelSm600
        case .regular: return .labelBase600
        case .bold: return .labelMd700
        }
    }
}

/// A bulleted info line (icon + text) under a row title. (Reference `ParagraphItem`.)
public struct ListRowInfo: Identifiable {
    public let id = UUID()
    let systemImage: String?
    let text: String
    public init(systemImage: String? = nil, _ text: String) {
        self.systemImage = systemImage
        self.text = text
    }
}

public struct ListRow: View {
    private let title: String
    private let subtitle: String?
    private let number: Int?
    private let size: ListRowSize
    private let leadingSystemImage: String?
    private let leadingImageURL: URL?
    private let leadingSelection: Binding<Bool>?
    private let alertCount: Int?
    private let badge: String?
    private let meta: ListRowMeta?
    private let infos: [ListRowInfo]
    private let isSelected: Bool
    private let multilineTitle: Bool
    private let infoAction: (() -> Void)?
    private let trailing: ListRowTrailing
    private let action: (() -> Void)?

    public init(
        _ title: String,
        subtitle: String? = nil,
        number: Int? = nil,
        size: ListRowSize = .regular,
        leadingSystemImage: String? = nil,
        leadingImageURL: URL? = nil,
        leadingSelection: Binding<Bool>? = nil,
        alertCount: Int? = nil,
        badge: String? = nil,
        meta: ListRowMeta? = nil,
        infos: [ListRowInfo] = [],
        isSelected: Bool = false,
        multilineTitle: Bool = false,
        infoAction: (() -> Void)? = nil,
        trailing: ListRowTrailing = .chevron,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.number = number
        self.size = size
        self.leadingSystemImage = leadingSystemImage
        self.leadingImageURL = leadingImageURL
        self.leadingSelection = leadingSelection
        self.alertCount = alertCount
        self.badge = badge
        self.meta = meta
        self.infos = infos
        self.isSelected = isSelected
        self.multilineTitle = multilineTitle
        self.infoAction = infoAction
        self.trailing = trailing
        self.action = action
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: Theme.SpacingKey.md.value) {
                leadingView
                centerView
                Spacer(minLength: Theme.SpacingKey.sm.value)
                if let infoAction {
                    Button(action: infoAction) {
                        Icon(systemName: "info.circle", size: .sm, color: Theme.shared.text(.textTertiary))
                    }
                    .buttonStyle(.plain)
                }
                trailingView
            }
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .padding(.horizontal, isSelected ? Theme.SpacingKey.md.value : 0)
            .background(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .fill(isSelected ? Theme.shared.background(.bgHero).opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle(cornerRadius: Theme.RadiusKey.sm.value))
        .disabled(action == nil && !isInteractiveTrailing && leadingSelection == nil)
    }

    private var isInteractiveTrailing: Bool {
        switch trailing {
        case .toggle, .checkbox, .button: return true
        default: return false
        }
    }

    // MARK: Leading

    @ViewBuilder
    private var leadingView: some View {
        if let leadingSelection {
            RadioButton(isSelected: leadingSelection)
        } else if let leadingImageURL {
            RemoteImage(leadingImageURL, aspectRatio: 1, cornerRadius: Theme.RadiusKey.sm.value)
                .frame(width: 48, height: 48)
        } else if let number {
            Text(String(format: "%02d", number))
                .textStyle(.labelMd700)
                .foregroundStyle(isSelected ? Theme.shared.text(.textHero) : Theme.shared.text(.textPrimary))
                .monospacedDigit()
                .frame(width: 32, alignment: .leading)
        } else if let leadingSystemImage {
            ZStack {
                Circle().fill(Theme.shared.background(.bgElevatorTertiary)).frame(width: 40, height: 40)
                Icon(systemName: leadingSystemImage, size: .sm, color: Theme.shared.foreground(.fgHero))
            }
            .overlay(alignment: .topTrailing) {
                if let alertCount, alertCount > 0 {
                    Text(alertCount > 99 ? "99+" : "\(alertCount)")
                        .textStyle(.overline400)
                        .foregroundStyle(Theme.shared.foreground(.fgSecondary))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Theme.shared.background(.systemcolorsBgError), in: Capsule())
                        .offset(x: 6, y: -4)
                }
            }
        }
    }

    // MARK: Center (title / badge / subtitle / meta)

    private var centerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Text(title)
                    .textStyle(size.titleStyle)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
                    .lineLimit(multilineTitle ? nil : 1)
                if let badge {
                    Badge(badge, style: .info, variant: .soft, size: .small)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
                    .lineLimit(multilineTitle ? nil : 2)
            }
            if let meta { metaLine(meta) }
            if !infos.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(infos) { info in
                        HStack(alignment: .top, spacing: Theme.SpacingKey.xs.value) {
                            Image(systemName: info.systemImage ?? "circle.fill")
                                .font(.system(size: info.systemImage == nil ? 5 : 11))
                                .foregroundStyle(Theme.shared.text(.textTertiary))
                                .padding(.top, info.systemImage == nil ? 6 : 2)
                            Text(info.text)
                                .textStyle(.bodySm400)
                                .foregroundStyle(Theme.shared.text(.textSecondary))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func metaLine(_ meta: ListRowMeta) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let rating = meta.rating {
                HStack(spacing: 2) {
                    Text(meta.ratingLabel ?? String(format: "%.1f", rating))
                        .textStyle(.labelSm700)
                        .foregroundStyle(Theme.shared.text(.textPrimary))
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.shared.foreground(.systemcolorsFgWarning))
                }
                .fixedSize()
            }
            if let sentiment = meta.sentiment {
                Text(sentiment)
                    .textStyle(.labelSm600)
                    .foregroundStyle(Theme.shared.foreground(.systemcolorsFgSuccess))
                    .fixedSize()
            }
            if let commentLabel = meta.commentLabel {
                Text(commentLabel)
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textTertiary))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.top, 2)
    }

    // MARK: Trailing

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .chevron:
            Icon(systemName: "chevron.right", size: .sm, color: Theme.shared.text(.textTertiary))
                .mirrorsInRTL()
        case .value(let text):
            Text(text)
                .textStyle(.bodyBase400)
                .foregroundStyle(Theme.shared.text(.textSecondary))
        case .toggle(let binding):
            ThemeToggle(isOn: binding)
        case .checkmark(let on):
            if on {
                Icon(systemName: "checkmark", size: .sm, color: Theme.shared.foreground(.fgHero))
            }
        case .checkbox(let binding):
            Checkbox(isChecked: binding)
        case .button(let label, let buttonAction):
            LinkButton(label, size: .small, action: buttonAction)
        case .price(let price):
            priceView(price)
        case .status(let text, let systemImage):
            HStack(spacing: 2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.shared.foreground(.systemcolorsFgSuccess))
                }
                Text(text)
                    .textStyle(.labelSm600)
                    .foregroundStyle(Theme.shared.foreground(.systemcolorsFgSuccess))
            }
        }
    }

    private func priceView(_ price: ListRowPrice) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let each = price.each {
                HStack(spacing: 0) {
                    Text(each)
                        .textStyle(.labelBase700)
                        .foregroundStyle(Theme.shared.text(.textPrimary))
                    Text(" \(price.unit)")
                        .textStyle(.bodySm400)
                        .foregroundStyle(Theme.shared.text(.textTertiary))
                }
                Text("Toplam: \(price.total)")
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textTertiary))
            } else {
                Text(price.total)
                    .textStyle(.labelBase700)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
            }
        }
    }
}

/// A non-interactive section-header row inside a list (Reference menu `.secondary`).
public struct ListSectionHeader: View {
    private let title: String
    public init(_ title: String) { self.title = title }

    public var body: some View {
        Text(title.uppercased())
            .textStyle(.labelSm700)
            .foregroundStyle(Theme.shared.text(.textTertiary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.SpacingKey.sm.value)
    }
}

#Preview {
    struct Demo: View {
        @State var push = true
        @State var agree = false
        @State var plan = true
        var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    ListRow("Account", subtitle: "Profile & security", leadingSystemImage: "person.circle", action: {})
                    DividerView(size: .small)
                    ListRow("Notifications", trailing: .toggle($push))
                    DividerView(size: .small)
                    ListRow("Accept terms", leadingSystemImage: "doc.text", trailing: .checkbox($agree))
                    DividerView(size: .small)
                    ListRow("Premium plan", subtitle: "Billed monthly", number: 1, isSelected: plan,
                            trailing: .price(.init(total: "₺14.400", each: "₺1.200", unit: "/ ay")), action: { plan.toggle() })
                    DividerView(size: .small)
                    ListRow("Grand Hotel", subtitle: "İstanbul · Deniz manzarası",
                            leadingSystemImage: "building.2",
                            meta: ListRowMeta(rating: 8.4, sentiment: "Mükemmel", commentLabel: "1.284 yorum"),
                            trailing: .status("Müsait", systemImage: "checkmark.seal.fill"), action: {})
                    DividerView(size: .small)
                    ListRow("Update payment", trailing: .button("Düzenle", action: {}))
                }
                .padding()
            }
        }
    }
    return Demo()
}
