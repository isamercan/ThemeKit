//
//  AlertDialog.swift
//  ThemeKit
//  Created by İsa Mercan on 13.07.2026.
//
//  Organism. A modal alert dialog for critical confirmations that require the
//  user's attention and an explicit action (HeroUI Figma Kit V3 · AlertDialog).
//
//  Unlike the fixed-layout `Dialog`, this component is a *composition* whose three
//  regions each appear only when their content/config asks for it:
//
//    ┌───────────────────────────────┐
//    │  ● icon        (Alert Header)  │   ← icon and/or title, leading | center
//    │  Title                         │
//    │  Description…  (body / slot)   │   ← message string OR a custom .content slot
//    │            [Cancel] [Delete]   │   ← Alert Footer, horizontal | vertical | auto
//    └───────────────────────────────┘
//
//  The Alert Header mirrors the Figma variant properties (Type left|center, Show
//  icon, Show title). The Alert Footer mirrors its own (Type horizontal|vertical,
//  Show Button One/Two, swap) AND fixes the reported overflow bug: in `.auto`
//  (the default) two side-by-side buttons whose labels don't fit collapse to a
//  vertical stack via `ViewThatFits`, so long CTAs never clip or overlap. Mobile
//  (`.size(.mobile)`) stacks by default for reachability, matching the design.
//
//  Present it over a dimmed scrim by reusing the shared `DialogPresentation`
//  chrome (scrim fade, scale+fade card transition, optional swipe-to-dismiss)
//  through `.alertDialog(isPresented:) { AlertDialog(…) }`. The card is also a
//  plain `View`, so it can be embedded inline (as the Figma "Composition" and
//  "Sizes" boards show it) without any presentation chrome.
//

import SwiftUI

// MARK: - Variant vocabulary (Figma variant properties)

/// Alert Header `Type`: icon + title aligned to the leading edge (informative /
/// complex messages) or centered (short, high-impact confirmations). RTL-safe —
/// `.leading` follows the layout direction.
public enum AlertHeaderAlignment: String, CaseIterable, Sendable {
    case leading, center
}

/// Alert Footer `Type`. `.horizontal` places the buttons side by side (trailing
/// aligned), `.vertical` stacks them full-width, and `.auto` (default) tries
/// horizontal first and falls back to vertical when the labels don't fit —
/// the fix for footer buttons overflowing / overlapping at their natural width.
public enum AlertFooterLayout: String, CaseIterable, Sendable {
    case auto, horizontal, vertical
}

/// Dialog `Size`. Controls the card's maximum width; `.mobile` (viewports ≤599)
/// also stacks the footer by default and uses the larger button ramp, matching
/// the Figma mobile board.
public enum AlertDialogSize: String, CaseIterable, Sendable {
    case xs, sm, md, lg, mobile

    /// Max card width per the Figma "Sizes" board (XS 320 · SM 480 · MD 640 ·
    /// LG 800 · Mobile 393).
    var maxWidth: CGFloat {
        switch self {
        case .xs: return 320
        case .sm: return 480
        case .md: return 640
        case .lg: return 800
        case .mobile: return 393
        }
    }

    /// Mobile stacks the footer by default (reachability); the rest default to
    /// `.auto` (horizontal, wrapping only when it must).
    var defaultFooterLayout: AlertFooterLayout { self == .mobile ? .vertical : .auto }
}

// MARK: - Alert Header (molecule)

/// The Figma `_AlertHeader`: an optional icon "avatar" bubble over an optional
/// title. Both are presence-driven — omit the icon (no `.icon(_:)`) or the title
/// (nil) and that row simply doesn't render (Show icon / Show title). The bubble
/// is a neutral surface; only the glyph carries the intent `tone`, so a
/// destructive alert reads as a red glyph on the same neutral chip the design
/// uses across every intent.
private struct AlertHeaderView: View {
    @Environment(\.theme) private var theme

    let icon: String?
    let title: String?
    let tone: SemanticColor
    let alignment: AlertHeaderAlignment

    private var stackAlignment: HorizontalAlignment { alignment == .center ? .center : .leading }
    private var frameAlignment: Alignment { alignment == .center ? .center : .leading }
    private var textAlignment: TextAlignment { alignment == .center ? .center : .leading }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: Theme.SpacingKey.sm.value) {
            if let icon {
                iconBubble(icon)
            }
            if let title {
                Text(title)
                    .textStyle(.bodyMd500)               // Figma "Body base medium" — 16 / medium
                    .foregroundStyle(theme.text(.textPrimary))
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    /// 40×40 neutral-soft circle with the intent-tinted 16pt glyph (Figma Avatar).
    private func iconBubble(_ systemName: String) -> some View {
        Icon(systemName: systemName)
            .size(.sm)                                   // 16pt — Figma icon size
            .color(theme.resolve(tone).accent)
            .frame(width: 40, height: 40)
            .background(theme.resolve(.neutral).soft, in: Circle())
            .accessibilityHidden(true)                   // decorative; the title carries meaning
    }
}

// MARK: - Alert Footer (molecule)

/// A resolved footer button — its title, semantic color, variant and tap action.
/// Kept as data so the footer can lay the same buttons out horizontally or
/// vertically (and re-size them) without the call site repeating itself. The
/// `ThemeButton` itself is built inside `AlertFooterView` (a `@MainActor` view),
/// not here, so the data type stays a plain value.
private struct AlertFooterButton {
    let title: String
    let color: SemanticColor
    let variant: ButtonVariant
    let a11yID: String?
    var isLoading: Bool = false
    let action: () -> Void
}

/// The Figma `_AlertFooter`. Renders up to two buttons — Button One (primary,
/// intent-tinted, solid) and Button Two (secondary, neutral soft) — in the
/// chosen layout. `.horizontal` is trailing-aligned and compact; `.vertical`
/// is full-width with the primary on top; `.auto` measures the horizontal row
/// and drops to vertical only when the labels can't fit, so a long CTA pair
/// never clips or overlaps.
private struct AlertFooterView: View {
    let primary: AlertFooterButton?
    let secondary: AlertFooterButton?
    let layout: AlertFooterLayout
    let swap: Bool

    /// Visual order: horizontal reads [secondary, primary] (primary trailing);
    /// vertical reads [primary, secondary] (primary on top). `swap` reverses both.
    private var horizontalButtons: [AlertFooterButton] {
        order([secondary, primary].compactMap { $0 })
    }
    private var verticalButtons: [AlertFooterButton] {
        order([primary, secondary].compactMap { $0 })
    }
    private func order(_ b: [AlertFooterButton]) -> [AlertFooterButton] { swap ? b.reversed() : b }

    var body: some View {
        switch layout {
        case .horizontal:
            horizontalRow.frame(maxWidth: .infinity, alignment: .trailing)
        case .vertical:
            verticalStack
        case .auto:
            // Try the compact horizontal row; when the buttons' natural width
            // exceeds the card, fall back to the full-width vertical stack.
            // The alignment frame lives OUTSIDE `ViewThatFits` so it can never
            // mask the horizontal candidate's true (overflowing) width.
            ViewThatFits(in: .horizontal) {
                horizontalRow
                verticalStack
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// Compact, trailing-aligned row measured at the buttons' natural width so
    /// `.auto` can detect overflow. Small button ramp (Figma "Button sm").
    private var horizontalRow: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(Array(horizontalButtons.enumerated()), id: \.offset) { _, b in
                button(b, size: .small, fullWidth: false)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    /// Full-width stack, primary on top. Larger button ramp (Figma "Button base").
    private var verticalStack: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(Array(verticalButtons.enumerated()), id: \.offset) { _, b in
                button(b, size: .medium, fullWidth: true)
            }
        }
    }

    private func button(_ b: AlertFooterButton, size: ButtonSize, fullWidth: Bool) -> some View {
        ThemeButton(b.title, action: b.action)
            .color(b.color)
            .variant(b.variant)
            .size(size)
            .fullWidth(fullWidth)
            .loading(b.isLoading)
            .a11yID(b.a11yID)
    }
}

// MARK: - AlertDialog (organism)

/// A modal alert dialog composed of an Alert Header, an optional body (a message
/// string or a custom `.content { }` slot) and an Alert Footer. Content lives in
/// the initializer; every appearance/behavior axis is a chainable, order-free
/// modifier (R1–R5).
///
///     AlertDialog("Delete product", message: "This can't be undone.")
///         .icon("trash")
///         .tone(.error)
///         .primaryAction("Delete") { delete() }
///         .secondaryAction("Cancel") { dismiss() }
///         .closable { dismiss() }
///
/// Present it over a scrim with `.alertDialog(isPresented:) { … }`, or embed the
/// card inline. `tone` (default `.neutral`) tints the header glyph and the
/// primary button, so one token drives the dialog's intent.
public struct AlertDialog: View {
    @Environment(\.theme) private var theme

    private let title: String?
    private let message: String?

    // Appearance/behavior — mutated only through the modifiers below (R2).
    private var icon: String?
    private var tone: SemanticColor = .neutral
    private var headerAlignment: AlertHeaderAlignment = .leading
    private var size: AlertDialogSize = .sm
    private var footerLayout: AlertFooterLayout?          // nil → size's default
    private var swapActions = false
    private var isPrimaryLoading = false

    private var primaryTitle: String?
    private var primaryAction: (() -> Void)?
    private var secondaryTitle: String?
    private var secondaryAction: (() -> Void)?
    private var onClose: (() -> Void)?

    /// Custom body content replacing the built-in `message` text (forms, lists,
    /// media). `nil` → render the `message` string (if any).
    private var customBody: SlotContent?

    public init(_ title: String? = nil, message: String? = nil) {   // R1 — content only
        self.title = title
        self.message = message
    }

    private var resolvedFooterLayout: AlertFooterLayout { footerLayout ?? size.defaultFooterLayout }

    private var hasHeader: Bool { icon != nil || title != nil }
    private var hasBody: Bool { customBody != nil || message != nil }
    private var hasFooter: Bool { primaryAction != nil || secondaryAction != nil }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            // Header + body share the tighter "container" gap (Figma spacing/2).
            if hasHeader || hasBody {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                    if hasHeader {
                        AlertHeaderView(icon: icon, title: title, tone: tone, alignment: headerAlignment)
                    }
                    if hasBody { bodyView }
                }
            }
            if hasFooter { footerView }
        }
        .padding(Theme.SpacingKey.base.value)                        // Figma spacing/6 (24)
        .frame(maxWidth: size.maxWidth)
        .background(
            theme.background(.bgWhite),
            in: RoundedRectangle(cornerRadius: Theme.RadiusKey.base.value, style: .continuous)   // rounded-3xl (24)
        )
        .overlay(alignment: .topTrailing) { closeButton }
        .themeShadow(.elevated)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var bodyView: some View {
        if let customBody {
            customBody
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let message {
            Text(message)
                .textStyle(.bodyBase400)                             // Figma "Body sm" — 14 / regular
                .foregroundStyle(theme.text(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footerView: some View {
        AlertFooterView(
            primary: primaryTitle.flatMap { t in
                primaryAction.map {
                    AlertFooterButton(title: t, color: tone, variant: .solid,
                                      a11yID: "alertDialog.primary", isLoading: isPrimaryLoading, action: $0)
                }
            },
            secondary: secondaryTitle.flatMap { t in
                secondaryAction.map {
                    AlertFooterButton(title: t, color: .neutral, variant: .soft,
                                      a11yID: "alertDialog.secondary", action: $0)
                }
            },
            layout: resolvedFooterLayout,
            swap: swapActions
        )
    }

    @ViewBuilder
    private var closeButton: some View {
        if let onClose {
            Button(action: onClose) {
                Icon(systemName: "xmark")
                    .size(.xs)                                       // 12pt
                    .color(theme.text(.textPrimary))
                    .frame(width: 24, height: 24)
                    .background(theme.resolve(.neutral).soft, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(Theme.SpacingKey.md.value)                      // ≈ Figma top 16 / right 12 inset
            .accessibilityLabel(String(themeKit: "Close"))
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AlertDialog {
    /// Header icon (SF Symbol). Omit to hide the icon row (Figma "Show icon").
    func icon(_ systemName: String?) -> Self { copy { $0.icon = systemName } }

    /// Intent color tinting the header glyph and the primary button (default
    /// `.neutral`). Use `.error` for destructive confirms, `.primary` for a
    /// brand CTA, etc.
    func tone(_ color: SemanticColor) -> Self { copy { $0.tone = color } }

    /// Header `Type`: `.leading` (default) or `.center`.
    func headerAlignment(_ a: AlertHeaderAlignment) -> Self { copy { $0.headerAlignment = a } }

    /// Card size tier: `.xs` / `.sm` (default) / `.md` / `.lg` / `.mobile`.
    /// `.mobile` also stacks the footer by default.
    func size(_ s: AlertDialogSize) -> Self { copy { $0.size = s } }

    /// Footer `Type`: `.auto` (horizontal, wrapping to vertical when the labels
    /// don't fit), `.horizontal`, or `.vertical`. Unset → the size's default.
    func footerLayout(_ layout: AlertFooterLayout) -> Self { copy { $0.footerLayout = layout } }

    /// Reverse the footer buttons' visual order (Figma "Swap Button One / Two").
    func swapActions(_ on: Bool = true) -> Self { copy { $0.swapActions = on } }

    /// Button One — the primary/confirming action, tinted by `tone` (Figma
    /// "Show Button One"). Omit to hide it.
    func primaryAction(_ title: String, action: @escaping () -> Void) -> Self {
        copy { $0.primaryTitle = title; $0.primaryAction = action }
    }

    /// Button Two — the secondary/dismissing action, neutral (Figma "Show
    /// Button Two"). Omit to hide it.
    func secondaryAction(_ title: String, action: @escaping () -> Void) -> Self {
        copy { $0.secondaryTitle = title; $0.secondaryAction = action }
    }

    /// Show the top-trailing close (✕) button; `handler` fires on tap.
    func closable(_ handler: @escaping () -> Void) -> Self { copy { $0.onClose = handler } }

    /// Drive the primary button's loading state — the presenter shows a spinner
    /// and taps are blocked while `on`.
    func primaryLoading(_ on: Bool = true) -> Self { copy { $0.isPrimaryLoading = on } }

    /// Custom body content replacing the built-in `message` text (Figma
    /// "Description / Body" slot — forms, lists, media).
    func content<Body: View>(@ViewBuilder _ body: () -> Body) -> Self {
        copy { $0.customBody = SlotContent(body) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Presentation (reuses the shared Dialog scrim / transition / swipe)

private struct AlertDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let maskClosable: Bool
    let swipeToDismiss: Bool
    let card: () -> AlertDialog

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                DialogPresentation(
                    swipeToDismiss: swipeToDismiss,
                    onScrimTap: { if maskClosable { isPresented = false } },
                    onSwipeDismiss: { isPresented = false }
                ) {
                    card().padding(Theme.SpacingKey.base.value)
                }
            }
        }
        .animation(motion, value: isPresented)
    }
}

public extension View {
    /// Present an ``AlertDialog`` as a modal over a dimmed scrim, reusing the
    /// shared dialog chrome (fade scrim, scale+fade card transition, optional
    /// swipe-to-dismiss). Wire dismissal inside the card's own
    /// `primaryAction` / `secondaryAction` / `closable` handlers.
    ///
    ///     view.alertDialog(isPresented: $show) {
    ///         AlertDialog("Delete product", message: "This can't be undone.")
    ///             .icon("trash").tone(.error)
    ///             .primaryAction("Delete") { show = false; delete() }
    ///             .secondaryAction("Cancel") { show = false }
    ///     }
    ///
    /// `swipeToDismiss` adds the swipe-down drag (HeroUI `isSwipeable`), off by
    /// default. `maskClosable` (default true) closes on a scrim tap.
    func alertDialog(
        isPresented: Binding<Bool>,
        maskClosable: Bool = true,
        swipeToDismiss: Bool = false,
        @ViewBuilder content: @escaping () -> AlertDialog
    ) -> some View {
        modifier(AlertDialogModifier(
            isPresented: isPresented, maskClosable: maskClosable,
            swipeToDismiss: swipeToDismiss, card: content
        ))
    }
}

// MARK: - Previews

#Preview("Composition") {
    // Presentation organism — each case pins the card so a single frame shows the
    // full chrome per color scheme.
    PreviewMatrix("AlertDialog") {
        PreviewCase("Destructive · two actions") {
            AlertDialog("Delete product", message: "Are you sure you want to delete this product? This action cannot be undone.")
                .icon("trash").tone(.error)
                .primaryAction("Delete") {}
                .secondaryAction("Cancel") {}
                .closable {}
                .size(.sm)
        }
        PreviewCase("Neutral · single confirm") {
            AlertDialog("Low Disk Space", message: "You are running low on disk space. Delete unnecessary files to free up space.")
                .icon("externaldrive")
                .primaryAction("Confirm") {}
                .closable {}
                .size(.sm)
        }
        PreviewCase("Header · center") {
            AlertDialog("Discard changes?", message: "Your edits will be lost.")
                .icon("exclamationmark.triangle").tone(.warning)
                .headerAlignment(.center)
                .primaryAction("Discard") {}
                .secondaryAction("Keep editing") {}
                .footerLayout(.vertical)
                .size(.xs)
        }
    }
}

#Preview("Footer overflow → auto-stack") {
    // The reported bug: two long labels can't sit side by side, so `.auto`
    // (default) drops them to a full-width vertical stack instead of clipping.
    PreviewMatrix("AlertDialog · footer") {
        PreviewCase("Short labels → horizontal") {
            AlertDialog("Leave call?", message: "You can rejoin any time.")
                .icon("phone.down").tone(.error)
                .primaryAction("Leave") {}
                .secondaryAction("Cancel") {}
                .size(.xs)
        }
        PreviewCase("Long labels → auto-stacked") {
            AlertDialog("Unsaved changes", message: "You have edits that haven't been saved yet.")
                .icon("square.and.pencil").tone(.primary)
                .primaryAction("Save and continue editing") {}
                .secondaryAction("Discard all my recent changes") {}
                .size(.xs)
        }
        PreviewCase("Forced vertical (mobile)") {
            AlertDialog("Delete product", message: "This action cannot be undone.")
                .icon("trash").tone(.error)
                .primaryAction("Delete") {}
                .secondaryAction("Cancel") {}
                .size(.mobile)
        }
    }
}

#Preview("Sizes") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(AlertDialogSize.allCases, id: \.self) { s in
                AlertDialog("\(s.rawValue.uppercased()) · Delete product",
                            message: "Are you sure you want to delete this product? This action cannot be undone.")
                    .icon("trash").tone(.error)
                    .primaryAction("Delete") {}
                    .secondaryAction("Cancel") {}
                    .closable {}
                    .size(s)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    .background(Color.gray.opacity(0.1))
    .environment(Theme.shared)
}

#Preview("Presented + custom body slot") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State private var show = true
        var body: some View {
            Color.gray.opacity(0.1).ignoresSafeArea()
                .overlay {
                    PrimaryButton("Show alert") { show = true }
                }
                .alertDialog(isPresented: $show, swipeToDismiss: true) {
                    AlertDialog("Rate your stay")
                        .icon("star").tone(.warning)
                        .headerAlignment(.center)
                        .content {
                            VStack(spacing: Theme.SpacingKey.sm.value) {
                                Text("Any layout works here — ratings, forms, media.")
                                    .textStyle(.bodyBase400)
                                    .foregroundStyle(theme.text(.textSecondary))
                                    .multilineTextAlignment(.center)
                                HStack {
                                    ForEach(0..<5, id: \.self) { _ in
                                        Icon(systemName: "star.fill").size(.md).color(theme.resolve(.warning).accent)
                                    }
                                }
                            }
                        }
                        .primaryAction("Submit") { show = false }
                        .secondaryAction("Not now") { show = false }
                        .closable { show = false }
                }
        }
    }
    return Demo()
}
