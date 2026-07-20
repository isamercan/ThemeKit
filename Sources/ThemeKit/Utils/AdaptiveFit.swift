//
//  AdaptiveFit.swift
//  ThemeKit
//
//  iOS 15.6-floor compat (ADR-0007 §D2 rule 1 — single-path): the package's
//  replacement for two-candidate `ViewThatFits(in: .horizontal)` (iOS 16),
//  used by every former `ViewThatFits` site (AlertDialog, TripSearchCard,
//  TripSearchCardStyle, PassengerForm) so there is a single idiom and a single
//  test surface (`AdaptiveFitTests`).
//
//  How it decides (the measured-fit technique from the migration plan §3c):
//  a zero-height, full-width probe reads the proposed width, and a hidden
//  `fixedSize(horizontal:)` copy of the preferred child reads its ideal
//  width — the same quantity `ViewThatFits(in: .horizontal)` compares. When
//  the ideal width fits the proposal the preferred child renders, else the
//  compact one. Both probes re-measure on Dynamic Type and width changes.
//
//  No measurement loop by construction: neither probe's size depends on which
//  child is displayed (the width probe is a fixed zero-height row; the ideal
//  probe always measures the preferred child), so the decision inputs never
//  feed back through the decision. Pinned by `AdaptiveFitTests` together with
//  the first-frame behavior: until the first measurement lands the preferred
//  child renders (`ViewThatFits` also prefers its first candidate), and the
//  measurement settles within the initial layout pass.
//
//  Deliberate divergences from `ViewThatFits` (documented, snapshot-checked
//  at the call sites):
//  1. The helper spans the full proposed width instead of hugging the chosen
//     child — `alignment` positions the child within that span. Every
//     migrated site sat in a full-width context already.
//  2. At accessibility Dynamic Type sizes the compact candidate wins
//     synchronously, without measurement — the documented intent of every
//     migrated site, and the only reliable answer inside width-hugging
//     ancestors (see the body comment).
//
//  When the deployment floor rises past 16 this file is a deletion-checklist
//  entry (ADR-0007 §D6): swap sites back to `ViewThatFits(in: .horizontal)`.
//

import SwiftUI

/// Renders `preferred` when its ideal width fits the proposed width, else
/// `compact` — the iOS 15.6-floor replacement for a two-candidate
/// `ViewThatFits(in: .horizontal)`. Two-slot by design; nest for more
/// candidates.
package struct AdaptiveFit<Preferred: View, Compact: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let alignment: Alignment
    private let preferred: Preferred
    private let compact: Compact

    @State private var availableWidth: CGFloat?
    @State private var preferredIdealWidth: CGFloat?

    /// - Parameters:
    ///   - alignment: where the chosen child sits within the full-width span
    ///     (leading/trailing terms — RTL-safe).
    ///   - preferred: the wide candidate, shown whenever it fits.
    ///   - compact: the stacked fallback.
    package init(alignment: Alignment = .topLeading,
                 @ViewBuilder preferred: () -> Preferred,
                 @ViewBuilder compact: () -> Compact) {
        self.alignment = alignment
        self.preferred = preferred()
        self.compact = compact()
    }

    package var body: some View {
        // Accessibility Dynamic Type sizes stack synchronously — no
        // measurement, no transient wide frame. This is the documented intent
        // of every migrated site ("falls to the stacked layout at
        // accessibility sizes"), and it sidesteps the one case measurement
        // cannot decide reliably: inside a width-hugging ancestor, the
        // transiently displayed wide candidate inflates the ancestor, which
        // feeds back as "available" width equal to the candidate's own ideal.
        if dynamicTypeSize.isAccessibilitySize {
            compact
                .frame(maxWidth: .infinity, alignment: alignment)
        } else {
            measuredFit
        }
    }

    private var measuredFit: some View {
        // A VStack, not a ZStack, and that is load-bearing: when the displayed
        // child overflows the proposal (the transient pre-measurement frame in
        // a too-narrow container), a ZStack re-proposes the inflated union
        // width to its other children, so the width probe would read the
        // overflow (200 for a 120 proposal), conclude "it fits", and deadlock
        // on the preferred child. A VStack keeps each child's first-pass
        // proposal, so the probe always reads the true available width —
        // verified by `AdaptiveFitTests`.
        VStack(alignment: .leading, spacing: 0) {
            // Zero-height width probe: expands to the proposed width without
            // adding height, carrying the hidden ideal-width probe of the
            // preferred child in an overlay so neither affects layout.
            Color.clear
                .frame(height: 0)
                .frame(maxWidth: .infinity)
                .background(WidthReporter<AvailableWidthKey>())
                .overlay(alignment: .topLeading) {
                    preferred
                        .fixedSize(horizontal: true, vertical: false)
                        .hidden()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .background(WidthReporter<PreferredIdealWidthKey>())
                }
            Group {
                if showsPreferred {
                    preferred
                } else {
                    compact
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment)
        }
        .onPreferenceChange(AvailableWidthKey.self) { availableWidth = $0 }
        .onPreferenceChange(PreferredIdealWidthKey.self) { preferredIdealWidth = $0 }
    }

    /// `ViewThatFits` semantics: first candidate whose ideal size fits wins;
    /// when none fits, the last candidate wins. Until the first measurement
    /// lands, the preferred (first) candidate renders.
    private var showsPreferred: Bool {
        guard let availableWidth, let preferredIdealWidth else { return true }
        // Exact comparison, like `ViewThatFits` — a synthetic tolerance flips
        // near-boundary decisions the system control would stack.
        return preferredIdealWidth <= availableWidth
    }
}

// MARK: - Probes

/// Reports the probed width through `Key` from a layout-neutral background.
private struct WidthReporter<Key: WidthPreferenceKey>: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: Key.self, value: proxy.size.width)
        }
    }
}

private protocol WidthPreferenceKey: PreferenceKey where Value == CGFloat {}

private struct AvailableWidthKey: WidthPreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PreferredIdealWidthKey: WidthPreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
