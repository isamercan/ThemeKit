//
//  InputGroup.swift
//  ThemeKit
//
//  HeroUI **InputGroup** (Figma HeroUI Kit V3 · node 13683-14530). A compact,
//  single-row field that groups an editable input with optional leading
//  (`prefix`) and trailing (`suffix`) *affixes* — icons, unit/label text, or
//  interactive selectors and actions (country code, currency, copy, reveal…).
//
//      InputGroup("heroui.com", text: $url)
//          .prefix { InputAffix().icon("globe") }
//          .suffix { InputAffix(action: copy).icon("doc.on.doc").emphasis(.active) }
//
//  Composition (Figma "Composition" board):
//    • Input — the text / number / password field (`.type(_:)`).
//    • Prefix — optional leading affix slot.
//    • Suffix — optional trailing affix slot.
//
//  Axes: `.variant(.primary|.secondary)` (page surface vs. on-card muted),
//  `.type(.text|.number|.password)`, `.gapSpaced(_:)` (flush vs. divided
//  segments). Each slot takes any view; `InputAffix` is the batteries-included
//  content. For floating labels, helper/error text or character counters use
//  `TextInput` instead — InputGroup is the low-level primitive.
//

import SwiftUI

// MARK: - Axes

/// InputGroup surface variant (Figma `variant`).
public enum InputGroupVariant: String, CaseIterable {
    /// White fill + soft elevation — regular page backgrounds / standard forms.
    case primary
    /// Muted on-surface fill, no elevation — for cards, modals, drawers, panels
    /// where the stock white field would disappear.
    case secondary
}

/// The kind of value the input holds (Figma `type`) — maps to keyboard + secure entry.
public enum InputGroupType: String, CaseIterable {
    case text, number, password
}

/// Visual emphasis of an affix's content (Figma "Affix Color").
public enum InputAffixEmphasis: String, CaseIterable {
    /// Passive / decorative content: placeholders, units, hints.
    case mute
    /// Interactive / currently-relevant content: selectors, actions, focus.
    case active
}

// Fixed field metrics from the Figma spec. The library's semantic spacing scale
// (4·8·16·24) is coarser than this compact 36pt field's 2·4·6·12 rhythm, so these
// stay as documented constants (the "genuine dimension, no token" escape) rather
// than mis-snapping to the nearest token.
private enum InputGroupMetrics {
    static let height: CGFloat = 36         // dimensions/spacing/9
    static let gapTight: CGFloat = 2        // dimensions/spacing/0.5 — gapSpaced == false
    static let gapWide: CGFloat = 12        // dimensions/spacing/3   — gapSpaced == true
    static let segmentPadding: CGFloat = 12 // dimensions/spacing/3   — affix horizontal inset
    static let iconGap: CGFloat = 6         // dimensions/spacing/1.5 — icon ↔ content group
    static let groupGap: CGFloat = 4        // dimensions/spacing/1   — content ↔ arrow
}

// MARK: - InputAffix

/// The leading / trailing content of an ``InputGroup`` (Figma "Input Affix").
/// Renders, in order, an optional icon, an optional short label, and an optional
/// selector arrow — tinted by `.emphasis(_:)`. Pass an `action` to make the whole
/// affix an interactive button (copy, reveal, open selector…).
///
///     InputAffix("USD").arrow().emphasis(.active)      // selector: label + chevron
///     InputAffix(action: copy).icon("doc.on.doc")      // icon button
///     InputAffix("https://")                           // static unit / prefix label
///
/// Icon-only interactive affixes should carry a spoken label:
/// `InputAffix(action: reveal).icon("eye").accessibilityLabel("Show password")`.
public struct InputAffix: View {
    @Environment(\.theme) private var theme

    private let content: String?
    private let action: (() -> Void)?
    // Appearance — mutated only through the modifiers below.
    private var systemImage: String?
    private var showsArrow = false
    private var emphasis: InputAffixEmphasis = .mute

    public init(_ content: String? = nil, action: (() -> Void)? = nil) {
        self.content = content
        self.action = action
    }

    private var tint: Color {
        emphasis == .active ? theme.text(.textPrimary) : theme.text(.textTertiary)
    }

    public var body: some View {
        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: InputGroupMetrics.iconGap) {
            if let systemImage {
                // Rendered as a plain SF Symbol (not the `Icon` atom) so it inherits
                // the affix's `foregroundStyle(tint)` for emphasis — the atom forces
                // its own tint. Sized from the icon token scale (sm = 16pt).
                Image(systemName: systemImage)
                    .font(.system(size: IconSize.sm.value))
                    .frame(width: IconSize.sm.value, height: IconSize.sm.value)
            }
            if content != nil || showsArrow {
                HStack(spacing: InputGroupMetrics.groupGap) {
                    if let content {
                        Text(content).textStyle(.bodyBase400)
                    }
                    if showsArrow {
                        Image(systemName: "chevron.down")
                            .font(.system(size: IconSize.xs.value, weight: .semibold))
                    }
                }
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, InputGroupMetrics.segmentPadding)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - InputAffix modifiers (copy-on-write · single mutation point)

public extension InputAffix {
    /// Leading SF Symbol glyph (16pt). `nil` removes it.
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }
    /// Show a trailing selector arrow (chevron), e.g. a country / currency picker.
    func arrow(_ show: Bool = true) -> Self { copy { $0.showsArrow = show } }
    /// Visual emphasis — `.mute` for passive units/hints, `.active` for interactive content.
    func emphasis(_ e: InputAffixEmphasis) -> Self { copy { $0.emphasis = e } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self { var c = self; mutate(&c); return c }
}

// MARK: - InputGroup

public struct InputGroup: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var text: String
    private let placeholder: String
    // Appearance — mutated only through the modifiers below.
    private var variant: InputGroupVariant = .primary
    private var type: InputGroupType = .text
    private var gapSpaced = false
    private var prefixSlot: SlotContent?
    private var suffixSlot: SlotContent?
    private var accessibilityID: String?

    @FocusState private var isFocused: Bool

    public init(_ placeholder: String = "", text: Binding<String>) {   // content + binding only
        self.placeholder = placeholder
        self._text = text
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
    }

    private var surfaceColor: Color {
        theme.background(variant == .primary ? .bgWhite : .bgSecondaryLight)
    }

    public var body: some View {
        HStack(spacing: gapSpaced ? InputGroupMetrics.gapWide : InputGroupMetrics.gapTight) {
            if let prefixSlot {
                segment(prefixSlot, dividerOn: .trailing)   // divider faces the input
            }
            field
            if let suffixSlot {
                segment(suffixSlot, dividerOn: .leading)     // divider faces the input
            }
        }
        .scaledControlHeight(InputGroupMetrics.height)
        .background(surfaceColor, in: shape)
        .overlay {
            // Focus ring (borderHero), matching the field family; the resting
            // border is transparent per the Figma spec.
            shape.strokeBorder(isFocused ? theme.border(.borderHero) : .clear,
                               lineWidth: isFocused ? 1.5 : 0)
        }
        .clipShape(shape)
        .modifier(OptionalSoftShadow(enabled: variant == .primary && isEnabled))
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityElement(children: .contain)
    }

    /// Wraps an affix slot: fills the row height and, when `gapSpaced`, draws a
    /// 1pt divider on its inner edge. `dividerOn` is layout-relative, so it mirrors
    /// automatically under RTL.
    @ViewBuilder
    private func segment(_ slot: SlotContent, dividerOn edge: Alignment) -> some View {
        slot
            .frame(maxHeight: .infinity)
            .overlay(alignment: edge) {
                if gapSpaced {
                    Rectangle().fill(theme.border(.borderPrimary)).frame(width: 1)
                }
            }
    }

    @ViewBuilder
    private var field: some View {
        Group {
            if type == .password {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .textStyle(.bodyBase400)
        .foregroundStyle(theme.text(.textPrimary))
        .tint(theme.border(.borderHero))
        .focused($isFocused)
        .disabled(!isEnabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Inset the value from the container edge only where no affix already pads
        // that side — next to an affix the value sits flush (Figma), matching the spec.
        .padding(.leading, prefixSlot == nil ? InputGroupMetrics.segmentPadding : 0)
        .padding(.trailing, suffixSlot == nil ? InputGroupMetrics.segmentPadding : 0)
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { isFocused = true } }
        // Number → number pad; text keeps autocaps/autocorrect, others opt out.
        #if os(iOS)
        .keyboardType(type == .number ? .numberPad : .default)
        .textInputAutocapitalization(type == .text ? .sentences : .never)
        .autocorrectionDisabled(type != .text)
        #endif
        .a11y(A11yElement.Field.field, in: accessibilityID)
    }
}

// MARK: - InputGroup modifiers (copy-on-write · single mutation point)

public extension InputGroup {
    /// Surface variant — `.primary` (white + elevation) or `.secondary` (on-card muted).
    func variant(_ v: InputGroupVariant) -> Self { copy { $0.variant = v } }
    /// Value kind — drives keyboard type and secure entry.
    func type(_ t: InputGroupType) -> Self { copy { $0.type = t } }
    /// Separate the affixes from the input with a divider + wider gap (Figma `gapSpace`).
    func gapSpaced(_ on: Bool = true) -> Self { copy { $0.gapSpaced = on } }
    /// Leading affix slot. Takes any view; `InputAffix` is the stock content.
    func prefix<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.prefixSlot = SlotContent(content) } }
    /// Trailing affix slot. Takes any view; `InputAffix` is the stock content.
    func suffix<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.suffixSlot = SlotContent(content) } }
    /// Stable accessibility identifier for UI tests.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self { var c = self; mutate(&c); return c }
}

// MARK: - Support

/// Applies the soft elevation token only for the primary variant (secondary is flat).
private struct OptionalSoftShadow: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.themeShadow(.soft) } else { content }
    }
}

// MARK: - Preview

#Preview {
    struct Demo: View {
        @State private var url = "heroui.com"
        @State private var amount = "10"
        @State private var phone = ""
        @State private var pass = "87$2h.3diua"
        @State private var reveal = false
        @State private var email = ""

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(InputGroupVariant.allCases, id: \.self) { variant in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(variant.rawValue.capitalized).textStyle(.labelSm600)

                            // URL: globe prefix + copy suffix
                            InputGroup("heroui.com", text: $url)
                                .variant(variant)
                                .prefix { InputAffix().icon("globe") }
                                .suffix { InputAffix(action: {}).icon("doc.on.doc").emphasis(.active)
                                    .accessibilityLabel("Copy") }

                            // Number: $ prefix + USD selector suffix, divided
                            InputGroup("0", text: $amount)
                                .variant(variant).type(.number).gapSpaced()
                                .prefix { InputAffix("$") }
                                .suffix { InputAffix("USD", action: {}).arrow().emphasis(.active) }

                            // Phone: country selector prefix
                            InputGroup("(000) 000 - 0000", text: $phone)
                                .variant(variant).type(.number).gapSpaced()
                                .prefix { InputAffix("+1", action: {}).icon("phone").arrow().emphasis(.active) }

                            // Password: reveal toggle suffix
                            InputGroup("Password", text: $pass)
                                .variant(variant).type(reveal ? .text : .password)
                                .suffix {
                                    InputAffix(action: { reveal.toggle() })
                                        .icon(reveal ? "eye.slash" : "eye")
                                        .accessibilityLabel(reveal ? "Hide password" : "Show password")
                                }

                            // Command hint suffix
                            InputGroup("Command", text: $email)
                                .variant(variant)
                                .suffix { InputAffix("⌘ K") }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.shared.background(.bgBase))
        }
    }
    return Demo().environment(Theme.shared)
}
