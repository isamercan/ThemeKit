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
//      // path == ["us", "ca", "berkeley"]  →  "Turkey / Istanbul / Berkeley"
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
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    /// Read-only subtree axis (set with `.readOnly(_:)`) — normal chrome, no picking.
    @Environment(\.isReadOnly) private var isReadOnly
    /// Subtree field-family defaults (F5) — fills `clearable` when not set explicitly.
    @Environment(\.fieldDefaults) private var fieldDefaults

    private let options: [CascaderOption]
    @Binding private var selection: [String]
    // Appearance — mutated only through the modifiers below.
    private var placeholder: String = String(themeKit: "Select")
    private var changeOnSelect = false
    /// Set only by the `.clearable(_:)` modifier, so the subtree
    /// `FieldDefaults.clearable` can fill the default without overriding an
    /// explicit per-field choice (F5): `explicitClearable ?? fieldDefaults.clearable ?? false`.
    private var explicitClearable: Bool?
    private var isSearchable = false
    private var isNodeEnabled: ((CascaderOption) -> Bool)?
    private var infoMessages: [InfoMessage] = []

    @State private var open = false
    @State private var browse: [String] = []
    @State private var query = ""

    public init(_ options: [CascaderOption], selection: Binding<[String]>) {   // R1
        self.options = options
        self._selection = selection
    }

    private var dominant: InfoMessage.Kind? { infoMessages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }
    /// Explicit `.clearable(_:)` → subtree `FieldDefaults.clearable` → off (F5).
    private var effectiveClearable: Bool { explicitClearable ?? fieldDefaults.clearable ?? false }
    private var showsClear: Bool { effectiveClearable && !selection.isEmpty && isEnabled && !isReadOnly }
    private func nodeEnabled(_ node: CascaderOption) -> Bool { isNodeEnabled?(node) ?? true }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            field
            if open { panel }
            if !infoMessages.isEmpty { InfoMessageList(infoMessages) }
        }
        .animation(.snappy(duration: 0.2), value: open)
        .animation(.snappy(duration: 0.2), value: browse)
    }

    /// Field border follows the dominant message kind, then the open state —
    /// same token order as the shared `FieldStyle` chrome.
    private var borderColor: Color {
        if hasError { return theme.border(.systemcolorsBorderError) }
        if hasWarning { return theme.border(.systemcolorsBorderWarning) }
        return theme.border(open ? .borderHero : .borderPrimary)
    }

    private var field: some View {
        ZStack(alignment: .trailing) {
            Button {
                // Read-only keeps the normal chrome + VoiceOver value but never
                // opens the columns (E1 — distinct from `.disabled`).
                guard !isReadOnly else { return }
                open.toggle()
                if open { browse = selection; query = "" }
            } label: {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Text(pathLabel(selection) ?? placeholder)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(selection.isEmpty ? theme.text(.textTertiary) : theme.text(.textPrimary))
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(showsClear ? .clear : theme.text(.textTertiary))
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .scaledControlHeight(44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
                .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value)
                    .strokeBorder(borderColor, lineWidth: open || hasError || hasWarning ? 2 : 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(pathLabel(selection) ?? "")

            if showsClear {
                Button { selection = []; browse = [] } label: {
                    Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
                .padding(.trailing, Theme.SpacingKey.md.value)
                .accessibilityLabel(String(themeKit: "Clear"))
            }
        }
    }

    /// The open dropdown: an optional search header (Ant `showSearch`), then
    /// either the level columns or — while a query is typed — a flat list of
    /// matched leaf paths.
    private var panel: some View {
        VStack(spacing: 0) {
            if isSearchable {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Icon(systemName: "magnifyingglass").size(.sm).color(theme.text(.textTertiary))
                    TextField(String(themeKit: "Search"), text: $query)
                        .textStyle(.bodyBase400)
                        .tint(theme.foreground(.fgHero))
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .scaledControlHeight(44)
                DividerView().size(.small)
            }
            if isSearchable && !query.isEmpty {
                searchResults
            } else {
                columns
            }
        }
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value).strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
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
    }

    private func column(_ opts: [CascaderOption], level: Int) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(opts) { opt in
                    let onPath = level < browse.count && browse[level] == opt.value
                    let enabled = nodeEnabled(opt)
                    Button { pick(opt, level: level) } label: {
                        HStack(spacing: Theme.SpacingKey.xs.value) {
                            Text(opt.label)
                                .textStyle(onPath ? .labelSm600 : .bodySm400)
                                .foregroundStyle(onPath ? theme.text(.textHero) : theme.text(.textPrimary))
                            Spacer(minLength: 4)
                            if !opt.isLeaf {
                                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.text(.textTertiary))
                                    .mirrorsInRTL()
                            }
                        }
                        .padding(.horizontal, Theme.SpacingKey.sm.value)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(onPath ? SemanticColor.primary.soft : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.4)
                }
            }
        }
        .frame(width: 150)
    }

    // MARK: Search (Ant `showSearch`)

    /// Leaf paths whose joined label matches `query`, skipping any path that
    /// crosses a `nodeEnabled(_:)`-disabled node.
    private var matchedPaths: [[CascaderOption]] {
        var out: [[CascaderOption]] = []
        func walk(_ opts: [CascaderOption], _ prefix: [CascaderOption]) {
            for opt in opts {
                guard nodeEnabled(opt) else { continue }
                let path = prefix + [opt]
                if opt.isLeaf {
                    let joined = path.map(\.label).joined(separator: " / ")
                    if joined.localizedCaseInsensitiveContains(query) { out.append(path) }
                } else {
                    walk(opt.children, path)
                }
            }
        }
        walk(options, [])
        return out
    }

    private var searchResults: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                let paths = matchedPaths
                if paths.isEmpty {
                    Text(String(themeKit: "No results"))
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textTertiary))
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .padding(.vertical, Theme.SpacingKey.sm.value)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                        Button {
                            selection = path.map(\.value)
                            browse = selection
                            open = false
                            query = ""
                        } label: {
                            Text(path.map(\.label).joined(separator: " / "))
                                .textStyle(.bodySm400)
                                .foregroundStyle(theme.text(.textPrimary))
                                .padding(.horizontal, Theme.SpacingKey.md.value)
                                .frame(height: 36)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxHeight: 220)
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
        guard nodeEnabled(opt) else { return }
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
    /// Show a trailing clear button when a path is selected (Ant `allowClear`).
    /// An explicit call wins over the subtree `FieldDefaults.clearable` default (F5).
    func clearable(_ on: Bool = true) -> Self { copy { $0.explicitClearable = on } }
    /// Add a search field atop the dropdown; typing filters to a flat list of
    /// matching leaf paths (Ant `showSearch`).
    func searchable(_ on: Bool = true) -> Self { copy { $0.isSearchable = on } }
    /// Per-node enable predicate; disabled nodes are greyed, unselectable, and
    /// excluded from search results (kit-standard `optionEnabled` idiom).
    func nodeEnabled(_ predicate: ((CascaderOption) -> Bool)?) -> Self { copy { $0.isNodeEnabled = predicate } }
    /// Validation / info messages rendered under the field (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    // The dropdown columns are tap-driven; each cell shows the field chrome as
    // a single static frame (open the demo to drive the cascading panels).
    let options = [
        CascaderOption("us", label: "United States", children: [
            CascaderOption("ca", label: "California", children: [
                CascaderOption("sf", label: "San Francisco"), CascaderOption("la", label: "Los Angeles")]),
            CascaderOption("ny", label: "New York", children: [CascaderOption("bk", label: "Brooklyn")])]),
        CascaderOption("de", label: "Germany", children: [
            CascaderOption("be", label: "Berlin", children: [CascaderOption("mitte", label: "Mitte")])]),
    ]
    PreviewMatrix("Cascader") {
        PreviewCase("Placeholder") {
            Cascader(options, selection: .constant([])).placeholder("Region")
        }
        // Searchable + clearable, with a disabled branch (E7 axes).
        PreviewCase("Selected · searchable + clearable") {
            Cascader(options, selection: .constant(["de", "be", "mitte"]))
                .searchable().clearable()
                .nodeEnabled { $0.value != "ny" }
        }
        // Validation message drives the error border.
        PreviewCase("Error message") {
            Cascader(options, selection: .constant([]))
                .infoMessages([InfoMessage("Pick a region", kind: .error)])
        }
        // Read-only: normal chrome + value, columns suppressed (E1).
        PreviewCase("Read-only") {
            Cascader(options, selection: .constant(["de", "be", "mitte"])).clearable().readOnly()
        }
    }
    .environment(Theme.shared)
}
