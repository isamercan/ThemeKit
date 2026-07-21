//
//  MeasuredLayoutSupport.swift
//  ThemeKit
//
//  iOS 15.6-floor compat (ADR-0007 §D2 rule 1 — single-path): the shared
//  measurement probes behind the measured layout containers (``FlowLayout``,
//  ``Masonry``, ``Flex``), which replaced their former `Layout` conformances
//  (`Layout`/`ProposedViewSize` are iOS 16). Same technique as ``AdaptiveFit``:
//  a zero-size probe reads the proposed span, and each child reports its
//  laid-out size through a preference keyed by its stable position index; the
//  container then packs frames with the exact math its old
//  `Layout.placeSubviews` used and places children with absolute offsets.
//
//  Nesting note: preferences bubble, so a measured container inside another
//  measured container would merge its child indices into its ancestor's
//  ledger. Every measured container therefore calls
//  ``consumesMeasuredLayoutPreferences()`` above its own readers to stop its
//  measurements at its own boundary.
//
//  When the deployment floor rises past 16 this file is a deletion-checklist
//  entry (ADR-0007 §D6): the three containers go back to `Layout`.
//

import SwiftUI

/// The width proposed to a measured container, read by a zero-height probe.
struct MeasuredLayoutWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// The height proposed to a measured container, read by a zero-width probe.
struct MeasuredLayoutHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Per-child measured sizes, keyed by the child's stable position index in the
/// container's variadic children.
struct MeasuredLayoutChildSizesKey: PreferenceKey {
    static let defaultValue: [Int: CGSize] = [:]
    static func reduce(value: inout [Int: CGSize], nextValue: () -> [Int: CGSize]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Report this child's laid-out size into the enclosing measured
    /// container's size ledger.
    func measuredLayoutChild(_ index: Int) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: MeasuredLayoutChildSizesKey.self, value: [index: proxy.size])
            }
        )
    }

    /// Stop this container's measurement preferences at its own boundary so a
    /// nested measured container can't corrupt an enclosing one's ledger.
    /// Apply *after* (outside) the container's own `onPreferenceChange`
    /// readers.
    func consumesMeasuredLayoutPreferences() -> some View {
        transformPreference(MeasuredLayoutWidthKey.self) { $0 = 0 }
            .transformPreference(MeasuredLayoutHeightKey.self) { $0 = 0 }
            .transformPreference(MeasuredLayoutChildSizesKey.self) { $0 = [:] }
    }
}

/// Zero-height row that expands to — and reports — the proposed width without
/// affecting the container's height.
struct MeasuredLayoutWidthProbe: View {
    var body: some View {
        Color.clear
            .frame(height: 0)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: MeasuredLayoutWidthKey.self, value: proxy.size.width)
                }
            )
            .accessibilityHidden(true)
    }
}

/// Zero-width column that expands to — and reports — the proposed height
/// without affecting the container's width.
struct MeasuredLayoutHeightProbe: View {
    var body: some View {
        Color.clear
            .frame(width: 0)
            .frame(maxHeight: .infinity)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: MeasuredLayoutHeightKey.self, value: proxy.size.height)
                }
            )
            .accessibilityHidden(true)
    }
}
