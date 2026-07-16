//
//  AlertDialog.swift
//  ThemeKit
//  Created by İsa Mercan on 13.07.2026.
//
//  Organism. A modal alert dialog for critical confirmations that require the
//  user's attention and an explicit action (HeroUI Figma Kit V3 · AlertDialog).
//
//  Unlike the fixed-layout `Dialog`, this is a *composition* of two public
//  molecules — `AlertHeader` and `AlertFooter` — plus an optional body. Each
//  region appears only when its content/config asks for it:
//
//    ┌───────────────────────────────┐
//    │  ● icon        (AlertHeader)   │   ← icon and/or title, leading | center
//    │  Title                         │
//    │  Description…  (body / slot)   │   ← message string OR a custom .content slot
//    │            [Cancel] [Delete]   │   ← AlertFooter, horizontal | vertical | auto
//    └───────────────────────────────┘
//
//  `AlertHeader` mirrors the Figma variant properties (Type left|center, Show
//  icon, Show title). `AlertFooter` mirrors its own (Type horizontal|vertical,
//  Show Button One/Two, swap) AND fixes the reported overflow bug: in `.auto`
//  (the default) two side-by-side buttons whose labels don't fit collapse to a
//  vertical stack via `ViewThatFits`, so long CTAs never clip or overlap. Mobile
//  (`.size(.mobile)`) stacks by default for reachability, matching the design.
//
//  Present it over a dimmed scrim — either building the card yourself with
//  `.alertDialog(isPresented:) { AlertDialog(…) }`, or the param convenience
//  `.alertDialog(isPresented:title:primaryTitle:onPrimary:…)` which drives an
//  async primary (spinner + auto-dismiss, Ant Modal `confirmLoading`). Both reuse
//  the shared `DialogPresentation` chrome (scrim fade, scale+fade transition,
//  optional swipe-to-dismiss). The molecules are plain `View`s too, so any of
//  them can be embedded inline (as the Figma boards show them).
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

// MARK: - AlertHeader (molecule)

/// The Figma `_AlertHeader`: an optional icon "avatar" bubble over an optional
/// title, aligned leading or center. Both are presence-driven — omit the icon
/// (no `.icon(_:)`) or the title (`AlertHeader()` with no text) and that row
/// doesn't render, covering the Show icon / Show title / icon-only / title-only
/// variants. The bubble is a neutral surface; only the glyph carries the intent
/// `tone`, so a destructive alert reads as a red glyph on the same neutral chip
/// the design uses across every intent.
///
///     AlertHeader("Delete product").icon("trash").tone(.error)   // icon + title
///     AlertHeader().icon("trash").tone(.error)                   // icon-only
///     AlertHeader("Discard changes?").alignment(.center)         // title-only, centered
public struct AlertHeader: View {
    @Environment(\.theme) private var theme

    private let title: String?
    private var icon: String?
    private var tone: SemanticColor = .neutral
    private var alignment: AlertHeaderAlignment = .leading

    public init(_ title: String? = nil) { self.title = title }   // R1 — content only

    private var stackAlignment: HorizontalAlignment { alignment == .center ? .center : .leading }
    private var frameAlignment: Alignment { alignment == .center ? .center : .leading }
    private var textAlignment: TextAlignment { alignment == .center ? .center : .leading }

    public var body: some View {
        VStack(alignment: stackAlignment, spacing: Theme.SpacingKey.sm.value) {
            if let icon {
                iconBubble(icon)
            }
            if let title {
                Text(title)
                    .textStyle(.bodyMd500)                       // Figma "Body base medium" — 16 / medium
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
            .size(.sm)                                           // 16pt — Figma icon size
            .color(theme.resolve(tone).accent)
            .frame(width: 40, height: 40)
            .background(theme.resolve(.neutral).soft, in: Circle())
            .accessibilityHidden(true)                           // decorative; the title carries meaning
    }
}

public extension AlertHeader {
    /// Icon (SF Symbol) shown in the bubble. Omit to hide it (Figma "Show icon").
    func icon(_ systemName: String?) -> Self { copy { $0.icon = systemName } }

    /// Intent color for the glyph (default `.neutral`); the bubble stays neutral.
    func tone(_ color: SemanticColor) -> Self { copy { $0.tone = color } }

    /// `Type`: `.leading` (default) or `.center`.
    func alignment(_ a: AlertHeaderAlignment) -> Self { copy { $0.alignment = a } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self { var c = self; mutate(&c); return c }
}

// MARK: - AlertFooter (molecule)

/// A resolved footer button — its title, semantic color, variant and tap action.
/// The `ThemeButton` is built inside `AlertFooter` (a `@MainActor` view), not
/// here, so the data type stays a plain value.
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
///
/// The primary action can be sync (`.primaryAction(_:action:)`) or async
/// (`.primaryAction(_:task:)`); the async form spins the button and blocks taps
/// until the work resolves (Ant `confirmLoading` / HeroUI pending state).
///
///     AlertFooter().tone(.error)
///         .primaryAction("Delete") { … }
///         .secondaryAction("Cancel") { … }
public struct AlertFooter: View {
    private var primaryTitle: String?
    private var primaryActionSync: (() -> Void)?
    private var primaryActionAsync: (() async -> Void)?
    private var secondaryTitle: String?
    private var secondaryAction: (() -> Void)?
    private var tone: SemanticColor = .neutral
    private var layout: AlertFooterLayout = .auto
    private var swap = false
    private var externalLoading = false

    /// Owns the async primary's in-flight state so the same declaration spins
    /// itself without the caller threading a `@State` through.
    @State private var isRunning = false

    public init() {}   // R1 — actions arrive via modifiers (ResultView parity)

    private var primaryLoading: Bool { externalLoading || isRunning }

    private var primaryButton: AlertFooterButton? {
        guard let primaryTitle else { return nil }
        let action: () -> Void
        if let async = primaryActionAsync {
            action = { Task { @MainActor in isRunning = true; await async(); isRunning = false } }
        } else {
            action = primaryActionSync ?? {}
        }
        return AlertFooterButton(title: primaryTitle, color: tone, variant: .solid,
                                 a11yID: "alertDialog.primary", isLoading: primaryLoading, action: action)
    }

    private var secondaryButton: AlertFooterButton? {
        guard let secondaryTitle, let secondaryAction else { return nil }
        return AlertFooterButton(title: secondaryTitle, color: .neutral, variant: .soft,
                                 a11yID: "alertDialog.secondary", action: secondaryAction)
    }

    /// Visual order: horizontal reads [secondary, primary] (primary trailing);
    /// vertical reads [primary, secondary] (primary on top). `swap` reverses both.
    private var horizontalButtons: [AlertFooterButton] { order([secondaryButton, primaryButton].compactMap { $0 }) }
    private var verticalButtons: [AlertFooterButton] { order([primaryButton, secondaryButton].compactMap { $0 }) }
    private func order(_ b: [AlertFooterButton]) -> [AlertFooterButton] { swap ? b.reversed() : b }

    public var body: some View {
        switch layout {
        case .horizontal:
            horizontalRow.frame(maxWidth: .infinity, alignment: .trailing)
        case .vertical:
            verticalStack
        case .auto:
            // Try the compact horizontal row; when the buttons' natural width
            // exceeds the card, fall back to the full-width vertical stack. The
            // alignment frame lives OUTSIDE `ViewThatFits` so it can never mask
            // the horizontal candidate's true (overflowing) width.
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

public extension AlertFooter {
    /// Button One — the primary/confirming action, tinted by `tone`. Sync form.
    func primaryAction(_ title: String, action: @escaping () -> Void) -> Self {
        copy { $0.primaryTitle = title; $0.primaryActionSync = action; $0.primaryActionAsync = nil }
    }

    /// Button One with an async task: the button spins and blocks taps until the
    /// work resolves (Ant `confirmLoading`). Dismiss inside the task if presented.
    func primaryAction(_ title: String, task: @escaping () async -> Void) -> Self {
        copy { $0.primaryTitle = title; $0.primaryActionAsync = task; $0.primaryActionSync = nil }
    }

    /// Button Two — the secondary/dismissing action, neutral (Figma "Show Button Two").
    func secondaryAction(_ title: String, action: @escaping () -> Void) -> Self {
        copy { $0.secondaryTitle = title; $0.secondaryAction = action }
    }

    /// Intent color for the primary button (default `.neutral`).
    func tone(_ color: SemanticColor) -> Self { copy { $0.tone = color } }

    /// `Type`: `.auto` (default), `.horizontal`, or `.vertical`.
    func layout(_ layout: AlertFooterLayout) -> Self { copy { $0.layout = layout } }

    /// Reverse the buttons' visual order (Figma "Swap Button One / Two").
    func swapActions(_ on: Bool = true) -> Self { copy { $0.swap = on } }

    /// Externally drive the primary button's loading state (in addition to the
    /// async `task:` form's own spinner).
    func primaryLoading(_ on: Bool = true) -> Self { copy { $0.externalLoading = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self { var c = self; mutate(&c); return c }
}

// MARK: - AlertDialog (organism)

/// A modal alert dialog composed of an ``AlertHeader``, an optional body (a
/// `message` string or a custom `.content { }` slot) and an ``AlertFooter``.
/// Content lives in the initializer; every appearance/behavior axis is a
/// chainable, order-free modifier (R1–R5).
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
    @Environment(\.dialogCornerRadius) private var cornerRadiusRole

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
    private var primaryActionSync: (() -> Void)?
    private var primaryActionAsync: (() async -> Void)?
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
    private var hasFooter: Bool { primaryTitle != nil || secondaryTitle != nil }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            // Header + body share the tighter "container" gap (Figma spacing/2).
            if hasHeader || hasBody {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                    if hasHeader {
                        AlertHeader(title).icon(icon).tone(tone).alignment(headerAlignment)
                    }
                    if hasBody { bodyView }
                }
            }
            if hasFooter { footer }
        }
        .padding(Theme.SpacingKey.base.value)                        // Figma spacing/6 (24)
        .frame(maxWidth: size.maxWidth)
        .background(
            theme.background(.bgWhite),
            in: RoundedRectangle(cornerRadius: theme.radius(cornerRadiusRole), style: .continuous)
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

    private var footer: AlertFooter {
        var f = AlertFooter()
            .tone(tone)
            .layout(resolvedFooterLayout)
            .swapActions(swapActions)
            .primaryLoading(isPrimaryLoading)
        if let primaryTitle {
            if let primaryActionAsync {
                f = f.primaryAction(primaryTitle, task: primaryActionAsync)
            } else {
                f = f.primaryAction(primaryTitle, action: primaryActionSync ?? {})
            }
        }
        if let secondaryTitle, let secondaryAction {
            f = f.secondaryAction(secondaryTitle, action: secondaryAction)
        }
        return f
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
        copy { $0.primaryTitle = title; $0.primaryActionSync = action; $0.primaryActionAsync = nil }
    }

    /// Button One with an async task: spins the button and blocks taps until the
    /// work resolves (Ant Modal `confirmLoading`). Dismiss inside the task when
    /// presented, or use the param `.alertDialog(…onPrimary:)` for auto-dismiss.
    func primaryAction(_ title: String, task: @escaping () async -> Void) -> Self {
        copy { $0.primaryTitle = title; $0.primaryActionAsync = task; $0.primaryActionSync = nil }
    }

    /// Button Two — the secondary/dismissing action, neutral (Figma "Show
    /// Button Two"). Omit to hide it.
    func secondaryAction(_ title: String, action: @escaping () -> Void) -> Self {
        copy { $0.secondaryTitle = title; $0.secondaryAction = action }
    }

    /// Show the top-trailing close (✕) button; `handler` fires on tap.
    func closable(_ handler: @escaping () -> Void) -> Self { copy { $0.onClose = handler } }

    /// Externally drive the primary button's loading state (in addition to any
    /// async `task:` action's own spinner).
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
                    backdrop: .dim,
                    placement: .center,
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

/// Param-based presenter that owns the async primary's loading + dismissal
/// (Ant Modal `confirmLoading` + `onOk`). Keeps the dialog up with a spinner
/// until `onPrimary` resolves, then dismisses.
private struct AlertDialogConfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String?
    let message: String?
    let icon: String?
    let tone: SemanticColor
    let headerAlignment: AlertHeaderAlignment
    let footerLayout: AlertFooterLayout?
    let size: AlertDialogSize
    let primaryTitle: String
    let onPrimary: () async -> Void
    let secondaryTitle: String?
    let onSecondary: (() -> Void)?
    let closable: Bool
    let maskClosable: Bool
    let swipeToDismiss: Bool

    @State private var primaryLoading = false
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                DialogPresentation(
                    swipeToDismiss: swipeToDismiss && !primaryLoading,
                    backdrop: .dim,
                    placement: .center,
                    onScrimTap: { if maskClosable, !primaryLoading { isPresented = false } },
                    onSwipeDismiss: { isPresented = false }
                ) {
                    card.padding(Theme.SpacingKey.base.value)
                }
            }
        }
        .animation(motion, value: isPresented)
    }

    private var card: AlertDialog {
        var d = AlertDialog(title, message: message)
            .icon(icon)
            .tone(tone)
            .headerAlignment(headerAlignment)
            .size(size)
            .primaryLoading(primaryLoading)
            .primaryAction(primaryTitle) {
                // Keep the dialog open with a spinner until the (possibly async)
                // work resolves, then dismiss (Ant Modal confirmLoading).
                Task { @MainActor in
                    primaryLoading = true
                    await onPrimary()
                    primaryLoading = false
                    isPresented = false
                }
            }
        if let footerLayout { d = d.footerLayout(footerLayout) }
        if let secondaryTitle {
            d = d.secondaryAction(secondaryTitle) {
                guard !primaryLoading else { return }
                isPresented = false
                onSecondary?()
            }
        }
        if closable {
            d = d.closable { if !primaryLoading { isPresented = false } }
        }
        return d
    }
}

public extension View {
    /// Present a caller-built ``AlertDialog`` as a modal over a dimmed scrim,
    /// reusing the shared dialog chrome (fade scrim, scale+fade transition,
    /// optional swipe-to-dismiss). Wire dismissal inside the card's own
    /// `primaryAction` / `secondaryAction` / `closable` handlers — this overload
    /// gives you full control over the card's content.
    ///
    ///     view.alertDialog(isPresented: $show) {
    ///         AlertDialog("Delete product", message: "This can't be undone.")
    ///             .icon("trash").tone(.error)
    ///             .primaryAction("Delete") { show = false; delete() }
    ///             .secondaryAction("Cancel") { show = false }
    ///     }
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

    /// Present an alert dialog from parameters, with the presenter driving the
    /// primary action's loading + dismissal automatically (Ant Modal
    /// `confirmLoading` / `onOk`): the dialog stays up with a spinner until the
    /// (possibly async) `onPrimary` resolves, then closes. Use this for the
    /// common confirm case; use the builder overload for custom content.
    ///
    ///     view.alertDialog(isPresented: $show, title: "Delete product",
    ///                      message: "This can't be undone.", icon: "trash",
    ///                      tone: .error, primaryTitle: "Delete",
    ///                      onPrimary: { await delete() },
    ///                      secondaryTitle: "Cancel", closable: true)
    func alertDialog(
        isPresented: Binding<Bool>,
        title: String? = nil,
        message: String? = nil,
        icon: String? = nil,
        tone: SemanticColor = .neutral,
        headerAlignment: AlertHeaderAlignment = .leading,
        footerLayout: AlertFooterLayout? = nil,
        size: AlertDialogSize = .sm,
        primaryTitle: String,
        onPrimary: @escaping () async -> Void = {},
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        closable: Bool = false,
        maskClosable: Bool = true,
        swipeToDismiss: Bool = false
    ) -> some View {
        modifier(AlertDialogConfirmModifier(
            isPresented: isPresented, title: title, message: message, icon: icon,
            tone: tone, headerAlignment: headerAlignment, footerLayout: footerLayout,
            size: size, primaryTitle: primaryTitle, onPrimary: onPrimary,
            secondaryTitle: secondaryTitle, onSecondary: onSecondary,
            closable: closable, maskClosable: maskClosable, swipeToDismiss: swipeToDismiss
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

#Preview("Header / footer variants") {
    PreviewMatrix("Alert header & footer") {
        PreviewCase("Icon-only header") {
            AlertHeader().icon("bell.badge").tone(.primary)
                .padding().frame(maxWidth: 240)
        }
        PreviewCase("Title-only header") {
            AlertHeader("Terms updated").padding().frame(maxWidth: 240)
        }
        PreviewCase("Center header") {
            AlertHeader("All set!").icon("checkmark.seal").tone(.success).alignment(.center)
                .padding().frame(maxWidth: 240)
        }
        PreviewCase("Footer · horizontal") {
            AlertFooter().tone(.error).primaryAction("Delete") {}.secondaryAction("Cancel") {}
                .layout(.horizontal).padding().frame(maxWidth: 320)
        }
        PreviewCase("Footer · auto-stacks long labels") {
            AlertFooter().tone(.primary)
                .primaryAction("Save and keep editing") {}
                .secondaryAction("Discard my changes") {}
                .padding().frame(maxWidth: 260)
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

#Preview("Presented · async primary + custom body") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State private var confirm = true
        @State private var rate = false
        var body: some View {
            Color.gray.opacity(0.1).ignoresSafeArea()
                .overlay {
                    VStack(spacing: 12) {
                        PrimaryButton("Delete (async)") { confirm = true }
                        OutlineButton("Rate (custom body)") { rate = true }
                    }
                }
                // Param convenience: spinner + auto-dismiss once the async work resolves.
                .alertDialog(isPresented: $confirm, title: "Delete product",
                             message: "Are you sure you want to delete this product? This action cannot be undone.",
                             icon: "trash", tone: .error, primaryTitle: "Delete",
                             onPrimary: { try? await Task.sleep(nanoseconds: 1_200_000_000) },
                             secondaryTitle: "Cancel", closable: true)
                // Builder overload with a custom body slot.
                .alertDialog(isPresented: $rate, swipeToDismiss: true) {
                    AlertDialog("Rate your stay")
                        .icon("star").tone(.warning)
                        .headerAlignment(.center)
                        .content {
                            HStack {
                                ForEach(0..<5, id: \.self) { _ in
                                    Icon(systemName: "star.fill").size(.md).color(theme.resolve(.warning).accent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .primaryAction("Submit") { rate = false }
                        .secondaryAction("Not now") { rate = false }
                        .closable { rate = false }
                }
        }
    }
    return Demo()
}
