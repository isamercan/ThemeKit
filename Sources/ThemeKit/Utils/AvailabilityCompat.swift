//
//  AvailabilityCompat.swift
//  ThemeKit
//
//  iOS 15.6-floor compat layer (ADR-0007). Two kinds of helper live here:
//
//  - **Single-path back-deploys** (§D2 rule 1): `onChangeCompat` gives every
//    call site the iOS 17 two-parameter `{ old, new in }` semantics on the
//    15.6 floor.
//  - **Graceful degrades** (§D2 rule 2): pure-polish modifiers
//    (`symbolEffect` bounce, numeric-text roll, scroll-target snapping) apply
//    natively on the OS that has them and become no-ops below — each through a
//    single named modifier so the degrade is one testable unit (§D2 rule 3),
//    never an ad-hoc inline `if #available`.
//
//  macOS never branches: the package's macOS 14 floor satisfies every macOS
//  availability requirement here, so `if #available(iOS …, *)` is statically
//  true on macOS (ADR-0007 §D1).
//
//  When the deployment floor rises past 17 again, this file is the deletion
//  checklist (ADR-0007 §D6).
//

import SwiftUI

// MARK: - onChange (two-parameter semantics, iOS 17 → 15.6)

package extension View {
    /// `.onChange(of:initial:_:)` with `{ old, new in }` semantics, back-deployed
    /// to the iOS 15.6 floor. On iOS 17+/macOS 14 it is the native modifier; below,
    /// the named ``LegacyOnChange`` unit synthesizes `old` from `@State` capture.
    func onChangeCompat<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial, action: action))
    }

    /// Zero-parameter overload mirroring iOS 17's `.onChange(of:initial:_:)`
    /// convenience for call sites that only care *that* the value changed.
    func onChangeCompat<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial, action: { _, _ in action() }))
    }
}

private struct OnChangeCompatModifier<V: Equatable>: ViewModifier {
    let value: V
    let initial: Bool
    let action: (V, V) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: value, initial: initial) { old, new in action(old, new) }
        } else {
            content.modifier(LegacyOnChange(value: value, initial: initial, action: action))
        }
    }
}

/// Named legacy unit (ADR-0007 §D2 rule 3) for two-parameter `onChange` below
/// iOS 17: the one-parameter `.onChange` plus a `@State` previous-value capture
/// that synthesizes `oldValue`.
///
/// Ordering contract (pinned by `OnChangeCompatTests`): `previous` starts at the
/// first render's value and is advanced *before* `action` runs, so rapid
/// sequential updates a→b→c report `(a,b)` then `(b,c)`, and updates SwiftUI
/// coalesces into one change report `(a,c)` — exactly the pairs the native
/// two-parameter modifier reports.
struct LegacyOnChange<V: Equatable>: ViewModifier {
    let value: V
    let initial: Bool
    let action: (V, V) -> Void

    @State private var previous: V
    @State private var firedInitial = false

    init(value: V, initial: Bool = false, action: @escaping (V, V) -> Void) {
        self.value = value
        self.initial = initial
        self.action = action
        _previous = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        content
            // One-parameter `.onChange` is deprecated from iOS 17 — this single,
            // deliberate use is the back-deploy vehicle and compiles warning-free
            // once the Package floor is 15.6 (Phase 4). ADR-0007 §D2 rule 1.
            .onChange(of: value) { newValue in
                let old = previous
                previous = newValue
                action(old, newValue)
            }
            .onAppear {
                // Native `initial: true` runs the action once on appearance with
                // old == new == current.
                guard initial, !firedInitial else { return }
                firedInitial = true
                action(value, value)
            }
    }
}

// MARK: - Symbol bounce (iOS 17 polish)

package extension View {
    /// `.symbolEffect(.bounce, value:)` back-deployed: bounces on iOS 17+ and
    /// renders the static symbol below — pure polish, no capability loss
    /// (ADR-0007 §D2 rule 2). Call sites keep gating the `value` driver through
    /// `MicroMotion`/Reduce-Motion exactly as before; this unit only owns the
    /// availability split.
    func symbolBounceCompat<V: Equatable>(value: V) -> some View {
        modifier(SymbolBounceCompat(value: value))
    }
}

/// Named degrade unit for `.symbolEffect(.bounce)` (ADR-0007 §D2 rule 3): the
/// `else` branch renders the unanimated symbol unchanged.
struct SymbolBounceCompat<V: Equatable>: ViewModifier {
    let value: V

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.symbolEffect(.bounce, value: value)
        } else {
            content
        }
    }
}

// MARK: - Content transitions (iOS 16 modifier; `.numericText(value:)` is 17)

package extension View {
    /// `.contentTransition(.numericText(value:))` back-deployed at each API's
    /// true floor: directed numeric roll on iOS 17+, undirected `.numericText()`
    /// on iOS 16, and a plain swap below 16 (ADR-0007 §D2 rule 2).
    /// `enabled: false` applies `.identity` where the modifier exists, keeping
    /// today's Reduce-Motion behavior byte-identical.
    func numericTextTransitionCompat(_ enabled: Bool, value: Double) -> some View {
        modifier(NumericTextTransitionCompat(enabled: enabled, value: value))
    }

    /// `.contentTransition(enabled ? .numericText() : .identity)` back-deployed:
    /// native on iOS 16+, plain swap below.
    func numericTextTransitionCompat(_ enabled: Bool) -> some View {
        modifier(NumericTextTransitionCompat(enabled: enabled, value: nil))
    }

    /// `.contentTransition(.opacity)` back-deployed: cross-fade on iOS 16+,
    /// plain swap below.
    func opacityContentTransitionCompat() -> some View {
        modifier(OpacityContentTransitionCompat())
    }
}

/// Named degrade unit for the numeric-text roll (ADR-0007 §D2 rule 3): below
/// iOS 16 the text swaps with no content transition.
struct NumericTextTransitionCompat: ViewModifier {
    let enabled: Bool
    /// Drives the iOS 17 directed roll; `nil` uses the undirected 16+ form only.
    let value: Double?

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *), let value {
            content.contentTransition(enabled ? .numericText(value: value) : .identity)
        } else if #available(iOS 16.0, *) {
            content.contentTransition(enabled ? .numericText() : .identity)
        } else {
            content
        }
    }
}

/// Named degrade unit for `.contentTransition(.opacity)` (ADR-0007 §D2 rule 3).
struct OpacityContentTransitionCompat: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.contentTransition(.opacity)
        } else {
            content
        }
    }
}

// MARK: - Scroll-target snapping cluster (iOS 17 polish)

package extension View {
    /// `.scrollTargetLayout()` back-deployed: no-op below iOS 17, where the
    /// carousel degrades to plain scrolling (ADR-0007 §D2 rule 2).
    func scrollTargetLayoutCompat() -> some View {
        modifier(ScrollTargetLayoutCompat())
    }

    /// `.scrollTargetBehavior(.viewAligned)` back-deployed: no snap below iOS 17.
    func viewAlignedScrollCompat() -> some View {
        modifier(ViewAlignedScrollCompat())
    }

    /// `.scrollClipDisabled()` back-deployed: content clips at the scroll
    /// bounds below iOS 17.
    func scrollClipDisabledCompat() -> some View {
        modifier(ScrollClipDisabledCompat())
    }

    /// `.scrollPosition(id:anchor:)` back-deployed: below iOS 17 the binding is
    /// simply not wired — programmatic scroll restoration is polish on top of a
    /// still-fully-scrollable strip (ADR-0007 §D2 rule 2).
    func scrollPositionCompat<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        modifier(ScrollPositionCompat(id: id, anchor: anchor))
    }
}

/// Named degrade units for the scroll-target cluster (ADR-0007 §D2 rule 3):
/// each `else` branch is the plain, un-snapped scroll content.
struct ScrollTargetLayoutCompat: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) { content.scrollTargetLayout() } else { content }
    }
}

struct ViewAlignedScrollCompat: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) { content.scrollTargetBehavior(.viewAligned) } else { content }
    }
}

struct ScrollClipDisabledCompat: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) { content.scrollClipDisabled() } else { content }
    }
}

struct ScrollPositionCompat<ID: Hashable>: ViewModifier {
    @Binding var id: ID?
    let anchor: UnitPoint?

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollPosition(id: $id, anchor: anchor)
        } else {
            content
        }
    }
}

// MARK: - Popover compact adaptation (iOS 16.4)

package extension View {
    /// `.presentationCompactAdaptation(.popover)` back-deployed: on iOS 16.4+
    /// a popover stays a popover in compact size classes; below it adapts to
    /// the pre-16.4 system default (a sheet) — pure presentation polish
    /// (ADR-0007 §D2 rule 2). macOS popovers never adapt, so the modifier is
    /// iOS-only to begin with.
    func popoverCompactAdaptationCompat() -> some View {
        modifier(PopoverCompactAdaptationCompat())
    }
}

/// Named degrade unit (ADR-0007 §D2 rule 3) for `presentationCompactAdaptation`:
/// the `else` branch keeps the system's default compact adaptation (sheet).
struct PopoverCompactAdaptationCompat: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 16.4, *) {
            content.presentationCompactAdaptation(.popover)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - View-level strikethrough (iOS 16)

package extension View {
    /// View-level `.strikethrough` (iOS 16) back-deployed for arbitrary slot
    /// content: applies on 16+, no-op below (pure polish — the `Text`-label
    /// path keeps its line-through on every OS via the Text-level modifier).
    func strikethroughCompat(_ active: Bool) -> some View {
        modifier(StrikethroughCompat(active: active))
    }
}

/// Named degrade unit (ADR-0007 §D2 rule 3) for view-level strikethrough.
struct StrikethroughCompat: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.strikethrough(active)
        } else {
            content
        }
    }
}

// MARK: - Locale (iOS 16 `Locale.currency` / `Locale.region`)

package extension Locale {
    /// `currency?.identifier` back-deployed (that object-form API is iOS 16):
    /// the toll-free-bridged `NSLocale.currencyCode`, identical data on every
    /// supported OS (ADR-0007 §D2 rule 1 — single-path; companion to Core's
    /// `themeKitLanguageCode`).
    var themeKitCurrencyCode: String? { (self as NSLocale).currencyCode }

    /// `region?.identifier` back-deployed: the toll-free-bridged
    /// `NSLocale.countryCode` ("US", "TR", …) — single-path.
    var themeKitRegionCode: String? { (self as NSLocale).countryCode }
}

// MARK: - Accessibility announcements (iOS 17 `AccessibilityNotification`)

/// `AccessibilityNotification.Announcement(_:).post()` back-deployed: the
/// UIKit notification is the same capability on every supported iOS
/// (ADR-0007 §D2 rule 1 — single-path); macOS (floor 14) keeps the modern API.
package enum AccessibilityAnnouncement {
    @MainActor
    package static func post(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #else
        AccessibilityNotification.Announcement(message).post()
        #endif
    }
}

// MARK: - TextEditor backdrop (iOS 16 `.scrollContentBackground(.hidden)`)

package extension View {
    /// `.scrollContentBackground(.hidden)` back-deployed for `TextEditor`
    /// surfaces: native on iOS 16+; below, the named
    /// ``LegacyClearTextEditorBackground`` unit clears the backing
    /// `UITextView`'s opaque backdrop via the UIKit appearance proxy
    /// (ADR-0007 §Consequences — decided here, snapshot-pinned).
    func scrollContentBackgroundHiddenCompat() -> some View {
        modifier(ScrollContentBackgroundHiddenCompat())
    }
}

struct ScrollContentBackgroundHiddenCompat: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content.modifier(LegacyClearTextEditorBackground())
        }
    }
}

/// Named legacy unit (ADR-0007 §D2 rule 3): on iOS 15 the only lever over
/// `TextEditor`'s opaque `UITextView` backdrop is the UIKit appearance proxy.
/// Applied once, lazily, on first appearance of any ThemeKit multi-line editor.
///
/// Trade-off (accepted, documented): the proxy is process-wide, so a consumer's
/// *own* `UITextView`s created afterwards also get a clear background on
/// iOS 15.x only. ThemeKit editors always draw their own token surface behind
/// the editor, which is exactly why the backdrop must go.
struct LegacyClearTextEditorBackground: ViewModifier {
    @MainActor private static var activated = false

    func body(content: Content) -> some View {
        content.onAppear { Self.activate() }
    }

    @MainActor static func activate() {
        guard !activated else { return }
        activated = true
        #if canImport(UIKit)
        UITextView.appearance().backgroundColor = .clear
        #endif
    }
}
