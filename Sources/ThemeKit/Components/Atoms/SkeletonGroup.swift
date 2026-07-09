//
//  SkeletonGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 09.07.2026.
//
//  Coordinates many skeleton placeholders with one loading flag (HeroUI Native
//  `SkeletonGroup`). The group publishes its loading flag into a private
//  environment key; the items are the *existing* `Skeleton` atom and the new
//  zero-argument `.skeleton()` / `.skeleton(shape:)` overloads below, which read
//  that key and forward to the existing `.skeleton(isLoading:)` modifier — so
//  one flag drives every placeholder, while each shimmer animates independently.
//  An explicitly passed `isLoading` always overrides the group.
//
//    SkeletonGroup {
//        Text(post.title).textStyle(.headingSm).skeleton()   // no flag — group-driven
//        Text(post.body).skeleton()
//    }
//    .loading(isLoading)
//
//  `.skeletonOnly()` marks a layout-only placeholder group (HeroUI
//  `isSkeletonOnly`): when loading ends the whole group renders `EmptyView`,
//  so wrapper stacks that exist purely to lay out `Skeleton` blocks collapse
//  instead of leaving empty space behind.
//

import SwiftUI

// MARK: - Group state (private environment plumbing)

private struct SkeletonGroupKey: EnvironmentKey {
    /// `nil` — not inside a `SkeletonGroup`; group-driven skeletons render
    /// their content unchanged. Computed (not `static let`) to match
    /// `ThemeEnvironmentKey` — Swift 6 strict concurrency house precedent.
    static var defaultValue: Bool? { nil }
}

fileprivate extension EnvironmentValues {
    /// The nearest enclosing `SkeletonGroup`'s loading flag, or `nil` outside
    /// any group.
    var skeletonGroupIsLoading: Bool? {
        get { self[SkeletonGroupKey.self] }
        set { self[SkeletonGroupKey.self] = newValue }
    }
}

// MARK: - SkeletonGroup

/// Drives every group-bound skeleton in `content` from one loading flag.
/// Each placeholder's shimmer animates independently; the group synchronizes
/// only *whether* they show, not their sweep.
///
/// Items opt in with the zero-argument `.skeleton()` / `.skeleton(shape:)`
/// modifiers (group-driven) or compose the standalone `Skeleton` atom inside a
/// `.skeletonOnly()` group. Passing an explicit flag — `.skeleton(true)` —
/// bypasses the group entirely.
///
/// While loading, the group reads to assistive technology as a single busy
/// region labeled "Loading" instead of N meaningless shimmers.
public struct SkeletonGroup<Content: View>: View {
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let content: Content
    // Appearance/config — mutated only through the modifiers below (R2).
    private var isLoading = true
    private var isSkeletonOnly = false

    public init(@ViewBuilder content: () -> Content) {   // R1 — content only
        self.content = content()
    }

    public var body: some View {
        Group {
            // A skeleton-only group has nothing to show once loading ends —
            // resolve to nothing at all so layout wrappers collapse.
            if isLoading || !isSkeletonOnly {
                content
                    .environment(\.skeletonGroupIsLoading, isLoading)
                    .modifier(SkeletonGroupAccessibility(isLoading: isLoading))
                    .transition(.opacity)
            }
        }
        // Cross-fade the flip (and the skeleton-only removal), honoring the
        // `microAnimations` switch and Reduce Motion exactly like Skeleton does.
        .animation(MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion), value: isLoading)
    }
}

/// One busy region labeled "Loading" while loading; a plain container of
/// ordinary children — no label — once loaded.
private struct SkeletonGroupAccessibility: ViewModifier {
    let isLoading: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isLoading {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(themeKit: "Loading"))
        } else {
            content
                .accessibilityElement(children: .contain)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SkeletonGroup {
    /// Drive every group-bound skeleton below from this one flag
    /// (same verb as `ListView.loading()` / `Card.loading()`).
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Mark the group as a pure placeholder (HeroUI `isSkeletonOnly`): its
    /// content exists only to lay out skeleton blocks, so when loading ends the
    /// whole group renders `EmptyView` and its layout wrappers collapse.
    func skeletonOnly(_ on: Bool = true) -> Self { copy { $0.isSkeletonOnly = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Group-driven items

/// Forwards the group's flag to the existing `.skeleton(isLoading:shape:)`
/// modifier; outside a group it renders the content unchanged.
private struct GroupSkeletonModifier: ViewModifier {
    @Environment(\.skeletonGroupIsLoading) private var groupIsLoading

    let shape: SkeletonShape
    private var isLoading: Bool { groupIsLoading ?? false }

    func body(content: Content) -> some View {
        content
            .skeleton(isLoading, shape: shape)
            // The placeholder region carries no information of its own — the
            // group announces a single "Loading" element instead.
            .accessibilityHidden(isLoading)
    }
}

public extension View {
    /// Replaces the view with a shimmering rounded skeleton while the nearest
    /// enclosing `SkeletonGroup` is loading. Outside a group the view renders
    /// unchanged; pass an explicit flag — `.skeleton(true)` — to override the group.
    func skeleton(cornerRadius: CGFloat = 8) -> some View {
        modifier(GroupSkeletonModifier(shape: .rounded(cornerRadius)))
    }

    /// Group-driven skeleton with a custom outline (see `skeleton(cornerRadius:)`).
    func skeleton(shape: SkeletonShape) -> some View {
        modifier(GroupSkeletonModifier(shape: shape))
    }
}

// MARK: - Previews

#Preview("Group loading toggle") {
    @Previewable @State var isLoading = true
    @Previewable @Environment(\.theme) var theme

    VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
        Toggle("Loading", isOn: $isLoading)

        SkeletonGroup {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                Text("Weekend in Lisbon").textStyle(.headingSm)
                    .foregroundStyle(theme.text(.textPrimary))
                    .skeleton()
                Text("Three days of tiles, trams and pastel facades by the river.")
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textSecondary))
                    .skeleton()
                Text("Updated today").textStyle(.labelSm600)
                    .foregroundStyle(theme.text(.textTertiary))
                    .skeleton(shape: .capsule)
            }
        }
        .loading(isLoading)
    }
    .padding(Theme.SpacingKey.md.value)
}

#Preview("Skeleton-only card") {
    @Previewable @State var isLoading = true

    VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
        Toggle("Loading", isOn: $isLoading)

        // Pure placeholder: the HStack/VStack exist only for layout, so the
        // whole group collapses to nothing once loading ends.
        SkeletonGroup {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Skeleton(.circle).size(width: 48, height: 48)
                VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                    Skeleton(.capsule).size(width: 160, height: 12)
                    Skeleton(.capsule).size(width: 100, height: 12)
                }
            }
        }
        .skeletonOnly()
        .loading(isLoading)

        Text("Content below moves up when the placeholder collapses.")
            .textStyle(.bodySm400)
    }
    .padding(Theme.SpacingKey.md.value)
}

#Preview("Per-item explicit override") {
    @Previewable @Environment(\.theme) var theme

    // The group has finished loading, but one item pins itself with an
    // explicit flag — explicit `isLoading` always beats the group.
    SkeletonGroup {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Text("Follows the group (loaded)").textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
                .skeleton()
            Text("Explicit .skeleton(true) — still shimmering").textStyle(.bodyBase400)
                .skeleton(true)
        }
    }
    .loading(false)
    .padding(Theme.SpacingKey.md.value)
}

#Preview("Dark theme") {
    let dark = Theme()
    dark.loadTheme(named: Theme.defaultThemeName, dark: true)

    return VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
        SkeletonGroup {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                Text("Loading on a dark surface").textStyle(.headingSm).skeleton()
                Text("Skeleton tokens adapt to the dark theme automatically.")
                    .textStyle(.bodyBase400)
                    .skeleton()
            }
        }
        .loading(true)

        SkeletonGroup {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Skeleton(.circle).size(width: 40, height: 40)
                Skeleton(.capsule).size(width: 140, height: 12)
            }
        }
        .skeletonOnly()
        .loading(true)
    }
    .padding(Theme.SpacingKey.md.value)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(dark.background(.bgBase))
    .theme(dark)
    .preferredColorScheme(.dark)
}
