//
//  Cascader.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Cascader** — pick a value from a multi-level tree of
//  options, one column per level (Country → City → District). The field shows the
//  chosen path; tapping opens side-by-side columns where each choice reveals the
//  next level, and selecting a leaf commits the path.
//
//      Cascader(regions, selection: $path).placeholder("Region")
//      // path == ["tr", "34", "kadikoy"]  →  "Türkiye / İstanbul / Kadıköy"
//

import SwiftUI

/// One node in a ``Cascader`` tree. Leaves have no `children`.
public struct CascaderOption: Identifiable, Sendable {
    public let value: String
    public let label: String
    public var children: [CascaderOption]
    public init(_ value: String, label: String, children: [CascaderOption] = []) {
        self.value = value
        self.label = label
        self.children = children
    }
    public var id: String { value }
    var isLeaf: Bool { children.isEmpty }
}

public struct Cascader: View {
    @Environment(\.theme) private var theme

    private let options: [CascaderOption]
    @Binding private var selection: [String]
    // Appearance — mutated only through the modifiers below.
    private var placeholder: String = String(themeKit: "Select")
    private var changeOnSelect = false

    @State private var open = false
    @State private var browse: [String] = []

    public init(_ options: [CascaderOption], selection: Binding<[String]>) {   // R1
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            field
            if open { columns }
        }
        .animation(.snappy(duration: 0.2), value: open)
        .animation(.snappy(duration: 0.2), value: browse)
    }

    private var field: some View {
        Button {
            open.toggle()
            if open { browse = selection }
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Text(pathLabel(selection) ?? placeholder)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(selection.isEmpty ? theme.text(.textTertiary) : theme.text(.textPrimary))
                Spacer(minLength: Theme.SpacingKey.sm.value)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.text(.textTertiary))
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
            .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value)
                .strokeBorder(theme.border(open ? .borderHero : .borderPrimary), lineWidth: open ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var columns: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(levels.enumerated()), id: \.offset) { level, opts in
                    column(opts, level: level)
                    if level < levels.count - 1 {
                        Rectangle().fill(theme.border(.borderPrimary)).frame(width: 1)
                    }
                }
            }
        }
        .frame(maxHeight: 220)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value).strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
    }

    private func column(_ opts: [CascaderOption], level: Int) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(opts) { opt in
                    let onPath = level < browse.count && browse[level] == opt.value
                    Button { pick(opt, level: level) } label: {
                        HStack(spacing: Theme.SpacingKey.xs.value) {
                            Text(opt.label)
                                .textStyle(onPath ? .labelSm600 : .bodySm400)
                                .foregroundStyle(onPath ? theme.text(.textHero) : theme.text(.textPrimary))
                            Spacer(minLength: 4)
                            if !opt.isLeaf {
                                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.text(.textTertiary))
                            }
                        }
                        .padding(.horizontal, Theme.SpacingKey.sm.value)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(onPath ? SemanticColor.primary.soft : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 150)
    }

    /// The option lists to show, one per open level.
    private var levels: [[CascaderOption]] {
        var result: [[CascaderOption]] = [options]
        var current = options
        for value in browse {
            guard let opt = current.first(where: { $0.value == value }), !opt.isLeaf else { break }
            result.append(opt.children)
            current = opt.children
        }
        return result
    }

    private func pick(_ opt: CascaderOption, level: Int) {
        browse = Array(browse.prefix(level)) + [opt.value]
        if opt.isLeaf {
            selection = browse
            open = false
        } else if changeOnSelect {
            selection = browse
        }
    }

    private func pathLabel(_ path: [String]) -> String? {
        guard !path.isEmpty else { return nil }
        var labels: [String] = []
        var current = options
        for value in path {
            guard let opt = current.first(where: { $0.value == value }) else { break }
            labels.append(opt.label)
            current = opt.children
        }
        return labels.isEmpty ? nil : labels.joined(separator: " / ")
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension Cascader {
    /// Hint shown when nothing is selected.
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }
    /// Commit the path at every level, not only on a leaf (Ant `changeOnSelect`).
    func changeOnSelect(_ on: Bool = true) -> Self { copy { $0.changeOnSelect = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var path: [String] = []
        let options = [
            CascaderOption("tr", label: "Türkiye", children: [
                CascaderOption("34", label: "İstanbul", children: [
                    CascaderOption("kadikoy", label: "Kadıköy"), CascaderOption("besiktas", label: "Beşiktaş")]),
                CascaderOption("06", label: "Ankara", children: [CascaderOption("cankaya", label: "Çankaya")])]),
            CascaderOption("de", label: "Deutschland", children: [
                CascaderOption("be", label: "Berlin", children: [CascaderOption("mitte", label: "Mitte")])]),
        ]
        var body: some View { Cascader(options, selection: $path).placeholder("Region").padding() }
    }
    return Demo().environment(Theme.shared)
}
