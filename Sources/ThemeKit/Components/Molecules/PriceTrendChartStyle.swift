//
//  PriceTrendChartStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 23.09.2026.
//
//  The styling door for ``PriceTrendChart``'s columns. The chart keeps everything that isn't
//  drawing — the points, which one is selected and the tap that changes it, the layout (the
//  stack, its spacing, the bar width, the scrolling), the header with its paging, the axis
//  overlay and the accessibility. A `PriceTrendChartStyle` draws one column: the value over the
//  bar, the bar, and the day under it.
//
//      FareCalendar()
//          .priceTrendChartStyle(MyChartStyle())   // every PriceTrendChart inside
//
//  It exists because a day is more than a bar. A fare calendar marks the day it is showing
//  inside its bar, greys a day it has no price for and puts a glyph there instead — none of
//  which a modifier can reach, and all of which are drawing, not behaviour.
//
//  While nobody sets a style, the chart draws its built-in columns exactly as before.
//  ``DefaultPriceTrendChartStyle`` (`.default`) draws that same look, so a custom style can hand
//  some columns back to it; setting `.default` explicitly restores the built-in path.
//

import SwiftUI

/// The inputs a ``PriceTrendChartStyle`` renders: one point, its place in the chart, and the
/// room the chart has measured out for it.
///
/// Fields a style doesn't use are simply ignored; new fields may be added in a minor release.
public struct PriceTrendChartStyleConfiguration {
    /// The day this column draws.
    public let point: PriceTrendPoint
    /// Its index among the points on screen — the value the chart's `selection` binding takes.
    public let index: Int
    /// Whether this is the selected day. The chart owns the selection; a style only draws it.
    public let isSelected: Bool
    /// The bar's height against the tallest point, 0…1. `barAreaHeight * fraction` is the
    /// height the built-in bar takes.
    public let fraction: CGFloat
    /// The vertical room the bar itself may take, with the value and the label already
    /// subtracted.
    public let barAreaHeight: CGFloat
    /// The room reserved under the bar for the day (and the weekday under it).
    public let labelReserve: CGFloat
    /// The room reserved over the bar for the value; `0` while ``showsValues`` is off.
    public let valueReserve: CGFloat
    /// The point's price, already formatted in the chart's currency and locale.
    public let priceText: String
    /// ``PriceTrendChart/showsValues(_:)`` — whether the chart makes room over the bars.
    public let showsValues: Bool
    /// ``PriceTrendChart/showsWeekday(_:)`` — whether the sublabel is drawn under the day.
    public let showsWeekday: Bool
    /// ``PriceTrendChart/accent(_:)``; `nil` means the hero foreground.
    public let accent: SemanticColor?
    /// ``PriceTrendChart/selectionAccent(_:)``; `nil` means the primary text colour.
    public let selectionAccent: SemanticColor?
    /// The corner radius the built-in bar rounds its top with
    /// (``PriceTrendChart/cornerRadius(_:)``).
    public let cornerRadius: CGFloat
    /// Whether the chart is drawing its bars with a gradient
    /// (``PriceTrendChart/gradient(_:)``).
    public let usesGradient: Bool

    public init(point: PriceTrendPoint, index: Int, isSelected: Bool, fraction: CGFloat,
                barAreaHeight: CGFloat, labelReserve: CGFloat, valueReserve: CGFloat,
                priceText: String, showsValues: Bool, showsWeekday: Bool,
                accent: SemanticColor?, selectionAccent: SemanticColor?,
                cornerRadius: CGFloat, usesGradient: Bool) {
        self.point = point
        self.index = index
        self.isSelected = isSelected
        self.fraction = fraction
        self.barAreaHeight = barAreaHeight
        self.labelReserve = labelReserve
        self.valueReserve = valueReserve
        self.priceText = priceText
        self.showsValues = showsValues
        self.showsWeekday = showsWeekday
        self.accent = accent
        self.selectionAccent = selectionAccent
        self.cornerRadius = cornerRadius
        self.usesGradient = usesGradient
    }

    /// The height the built-in bar takes — `barAreaHeight * fraction`, never under 6pt so a
    /// cheap day is still something to tap.
    public var barHeight: CGFloat { max(6, barAreaHeight * fraction) }
}

/// Defines a ``PriceTrendChart``'s columns. Implement `makeBody` to draw one. Set a style with
/// `.priceTrendChartStyle(_:)` on a chart or any ancestor; without one, the chart draws its
/// built-in columns.
///
/// The style draws; the chart keeps the rest. A tap still moves the selection, the columns are
/// still laid out and sized by the chart, the header and axis are still the chart's, and each
/// column is still one accessibility element naming its day and price. The style's output fills
/// the column, so it should end with the day label to keep every column's baseline.
///
///     struct FareChartStyle: PriceTrendChartStyle {
///         func makeBody(configuration: PriceTrendChartStyleConfiguration) -> some View {
///             let c = configuration
///             VStack(spacing: 4) {
///                 Text(c.priceText).textStyle(.overline500)
///                 Spacer(minLength: 0)
///                 RoundedRectangle(cornerRadius: c.cornerRadius)
///                     .fill(c.isSelected ? Color.accentColor : Color.gray.opacity(0.2))
///                     .frame(height: c.barHeight)
///                     .overlay { if c.isSelected { Image(systemName: "checkmark") } }
///                 Text(c.point.label).frame(height: c.labelReserve, alignment: .top)
///             }
///         }
///     }
public protocol PriceTrendChartStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: PriceTrendChartStyleConfiguration) -> Body
}

/// The stock column — what the chart draws when no style is set: the selected day's price over
/// the bar, a gradient bar rounded at the top, and the day under it, in a capsule while it is
/// the selected one. Reads the active `\.theme`, so an injected theme re-skins it too.
public struct DefaultPriceTrendChartStyle: PriceTrendChartStyle, Sendable {
    public init() {}
    public func makeBody(configuration: PriceTrendChartStyleConfiguration) -> some View {
        DefaultPriceTrendColumn(configuration: configuration)
    }
}

/// Mirrors the chart's built-in column. `PriceTrendChartStyleTests` renders both and compares
/// the pixels, so the two can't drift apart unnoticed.
private struct DefaultPriceTrendColumn: View {
    let configuration: PriceTrendChartStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            if configuration.showsValues {
                Group {
                    if configuration.isSelected {
                        Text(configuration.priceText)
                            .textStyle(.overline500)
                            .foregroundStyle(theme.text(.textPrimary))
                            .fixedSize()
                    }
                }
                .frame(height: 14)
            }
            Spacer(minLength: 0)
            ThemeUnevenRoundedRect(topLeadingRadius: configuration.cornerRadius,
                                   topTrailingRadius: configuration.cornerRadius,
                                   style: .continuous)
                .fill(barFill)
                .frame(height: configuration.barHeight)
            labelBlock
        }
    }

    private var accent: Color {
        configuration.accent.map { theme.resolve($0).base } ?? theme.foreground(.fgHero)
    }

    private var barFill: AnyShapeStyle {
        configuration.usesGradient
            ? AnyShapeStyle(LinearGradient(colors: [accent, accent.opacity(0.5)],
                                           startPoint: .bottom, endPoint: .top))
            : AnyShapeStyle(accent)
    }

    private var selectionBackground: Color {
        configuration.selectionAccent.map { theme.resolve($0).base } ?? theme.text(.textPrimary)
    }

    private var selectionForeground: Color {
        configuration.selectionAccent.map { theme.resolve($0).onSolid } ?? theme.text(.textSecondaryInverse)
    }

    private var labelBlock: some View {
        VStack(spacing: 1) {
            if configuration.isSelected {
                Text(configuration.point.label)
                    .textStyle(.overline500)
                    .foregroundStyle(selectionForeground)
                    .fixedSize()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(selectionBackground, in: Capsule())
            } else {
                Text(configuration.point.label)
                    .textStyle(.overline500)
                    .foregroundStyle(theme.text(.textTertiary))
                    .fixedSize()
            }
            if configuration.showsWeekday, let sublabel = configuration.point.sublabel {
                Text(sublabel)
                    .textStyle(.overline400)
                    .foregroundStyle(theme.text(.textTertiary))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(height: configuration.labelReserve, alignment: .top)
    }
}

public extension PriceTrendChartStyle where Self == DefaultPriceTrendChartStyle {
    /// The stock column — the chart's built-in look. Setting it with
    /// `.priceTrendChartStyle(.default)` restores the built-in path.
    static var `default`: DefaultPriceTrendChartStyle { DefaultPriceTrendChartStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyPriceTrendChartStyle: PriceTrendChartStyle {
    /// `true` for the environment key's stock default below, and for
    /// ``DefaultPriceTrendChartStyle`` set explicitly. While it is set, the chart draws its
    /// built-in columns (unchanged from before this door existed). Any other style routes
    /// through `makeBody(configuration:)`.
    let isDefault: Bool
    private let _makeBody: @MainActor (PriceTrendChartStyleConfiguration) -> AnyView
    init<S: PriceTrendChartStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault || S.self == DefaultPriceTrendChartStyle.self
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: PriceTrendChartStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct PriceTrendChartStyleKey: EnvironmentKey {
    static let defaultValue = AnyPriceTrendChartStyle(DefaultPriceTrendChartStyle(), isDefault: true)
}

extension EnvironmentValues {
    var priceTrendChartStyle: AnyPriceTrendChartStyle {
        get { self[PriceTrendChartStyleKey.self] }
        set { self[PriceTrendChartStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``PriceTrendChartStyle`` for `PriceTrendChart`s in this view and its descendants.
    func priceTrendChartStyle<S: PriceTrendChartStyle>(_ style: sending S) -> some View {
        environment(\.priceTrendChartStyle, AnyPriceTrendChartStyle(style))
    }
}
