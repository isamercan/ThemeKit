//
//  PreviewMatrix.swift
//  ThemeKit
//

import SwiftUI

/// One labeled cell in a ``PreviewMatrix`` — a single named state of a component
/// (e.g. *Default*, *Loading*, *Disabled*, *Error*, *Long text*).
public struct PreviewCase {
    let label: String
    let content: AnyView

    public init<V: View>(_ label: String, @ViewBuilder _ content: () -> V) {
        self.label = label
        self.content = AnyView(content())
    }
}

/// Collects ``PreviewCase`` values written one-per-line (with `if` / `for` support)
/// into the array a ``PreviewMatrix`` renders.
@resultBuilder
public enum PreviewCaseBuilder {
    public static func buildExpression(_ expression: PreviewCase) -> [PreviewCase] { [expression] }
    public static func buildExpression(_ expression: [PreviewCase]) -> [PreviewCase] { expression }
    public static func buildBlock(_ components: [PreviewCase]...) -> [PreviewCase] { components.flatMap { $0 } }
    public static func buildOptional(_ component: [PreviewCase]?) -> [PreviewCase] { component ?? [] }
    public static func buildEither(first: [PreviewCase]) -> [PreviewCase] { first }
    public static func buildEither(second: [PreviewCase]) -> [PreviewCase] { second }
    public static func buildArray(_ components: [[PreviewCase]]) -> [PreviewCase] { components.flatMap { $0 } }
}

/// A preview scaffold that lays a component's labeled **states** out as rows and
/// renders each across appearance **columns** — light + dark by default, plus
/// optional accessibility-size and RTL strips — so a single `#Preview` covers the
/// *state × appearance* matrix at a glance instead of one happy-path snapshot.
///
/// The knob demos cover states interactively; this gives previews the same
/// systematic coverage (default / loading / disabled / error / long-text / dark)
/// for visual scanning and snapshotting.
///
/// ```swift
/// #Preview("States") {
///     PreviewMatrix("Tag", dynamicType: true) {
///         PreviewCase("Default")   { Tag("React") }
///         PreviewCase("Removable") { Tag("Filter", onRemove: {}) }
///         PreviewCase("Semantic")  { Tag("Error", style: .error, variant: .solid) }
///         PreviewCase("Long text") { Tag("a-very-long-keyword-value-here") }
///     }
/// }
/// ```
public struct PreviewMatrix: View {
    struct Column: Identifiable {
        let id = UUID()
        let label: String
        let scheme: ColorScheme
        let dynamicType: DynamicTypeSize
        let layout: LayoutDirection
    }

    private let title: String?
    private let cases: [PreviewCase]
    private let columns: [Column]

    /// - Parameters:
    ///   - title: optional heading shown above the matrix.
    ///   - schemes: appearance columns rendered for every case (default light + dark).
    ///   - dynamicType: when `true`, appends an `accessibility3` (XL) Dynamic-Type column.
    ///   - rtl: when `true`, appends a right-to-left column.
    ///   - cases: the labeled component states, one `PreviewCase` per line.
    public init(
        _ title: String? = nil,
        schemes: [ColorScheme] = [.light, .dark],
        dynamicType: Bool = false,
        rtl: Bool = false,
        @PreviewCaseBuilder _ cases: () -> [PreviewCase]
    ) {
        self.title = title
        self.cases = cases()
        var cols = schemes.map {
            Column(label: $0 == .dark ? "Dark" : "Light", scheme: $0, dynamicType: .large, layout: .leftToRight)
        }
        if dynamicType {
            cols.append(Column(label: "XL type", scheme: schemes.first ?? .light, dynamicType: .accessibility3, layout: .leftToRight))
        }
        if rtl {
            cols.append(Column(label: "RTL", scheme: schemes.first ?? .light, dynamicType: .large, layout: .rightToLeft))
        }
        self.columns = cols
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let title {
                    Text(title).font(.headline)
                }
                ForEach(Array(cases.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(columns) { column in
                                cell(item.content, in: column)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func cell(_ content: AnyView, in column: Column) -> some View {
        VStack(spacing: 4) {
            content
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(column.scheme == .dark ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.25))
                )
                .environment(\.colorScheme, column.scheme)
                .environment(\.dynamicTypeSize, column.dynamicType)
                .environment(\.layoutDirection, column.layout)
            if columns.count > 1 {
                Text(column.label).font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview("PreviewMatrix demo") {
    PreviewMatrix("Badge", dynamicType: true) {
        PreviewCase("Default") { Badge("Info").badgeStyle(.info) }
        PreviewCase("With icon") { Badge("Star").badgeStyle(.success).icon("star.fill") }
        PreviewCase("Long text") { Badge("a-rather-long-badge-label").badgeStyle(.warning) }
    }
}
