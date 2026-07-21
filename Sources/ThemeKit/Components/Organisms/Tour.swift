//
//  Tour.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Guided product tour: spotlights a target view through a dimmed scrim and
//  shows a step card with prev / next / skip. (Ant Tour.)
//
//  Usage:
//      @StateObject var tour = TourController()   // NOT @State — see TourController
//      someView.tourTarget("search")
//      rootView.tourHost(tour, steps: [TourStep("search", title: "Search", message: "…")])
//      tour.start()
//
//  Custom step card: `tourHost(_:steps:) { context in … }` swaps the card's
//  interior for a caller-drawn view; the scrim, spotlight cutout, highlight
//  ring, card shell, close button and positioning stay in the component, and
//  `TourStepContext` exposes the same next / prev / skip actions the built-in
//  card uses.
//
//  CardStyle exception: the step card deliberately does NOT read
//  `@Environment(\.cardStyle)`. It is spotlight balloon chrome floating over a
//  heavily dimmed scrim; ambient card styles are tuned for in-flow cards (e.g.
//  `.outlined` has a transparent surface, which would leave the step card
//  illegible against the scrim), and the card's position math assumes this
//  fixed shell.
//

import SwiftUI

public struct TourStep: Identifiable {
    public let id: String        // matches a `.tourTarget(id)`
    let title: String
    let message: String
    public init(_ id: String, title: String, message: String) {
        self.id = id; self.title = title; self.message = message
    }
}

/// Drives a tour hosted with `.tourHost(_:steps:)`.
///
/// > Important: iOS 15.6-floor migration (ADR-0007 §D4). `TourController` is an
/// > `ObservableObject` (the iOS-17 `@Observable` pattern no longer applies):
/// > own it as `@StateObject var tour = TourController()` — NOT `@State`, which
/// > still compiles but silently stops updating the hosting view.
public final class TourController: ObservableObject {
    @Published public var isActive = false
    @Published public var index = 0

    public init() {}

    public func start() { index = 0; isActive = true }
    public func stop() { isActive = false }

    func next(count: Int) {
        if index < count - 1 { index += 1 } else { isActive = false }
    }
    func prev() { if index > 0 { index -= 1 } }
}

struct TourAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Everything a custom step card needs: the current step, its position in the
/// flow, and the same navigation actions the built-in card wires to its buttons.
public struct TourStepContext {
    /// The step being presented.
    public let step: TourStep
    /// Zero-based index of the step.
    public let index: Int
    /// Total number of steps in the tour.
    public let count: Int
    /// Advances to the next step (finishes the tour on the last one).
    public let next: () -> Void
    /// Returns to the previous step (no-op on the first).
    public let prev: () -> Void
    /// Ends the tour immediately.
    public let skip: () -> Void
}

public extension View {
    /// Marks this view as a tour target with `id` (referenced by a `TourStep`).
    func tourTarget(_ id: String) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [id: $0] }
    }

    /// Hosts the tour overlay. Apply at the root that contains the targets.
    func tourHost(_ controller: TourController, steps: [TourStep]) -> some View {
        modifier(TourHostModifier(controller: controller, steps: steps))
    }

    /// Hosts the tour overlay with a fully custom step-card interior. The scrim,
    /// spotlight cutout, highlight ring, card shell (surface, shadow, close
    /// button) and positioning are unchanged; `stepCard` draws the inside and
    /// drives navigation through the passed ``TourStepContext``.
    func tourHost<StepCard: View>(
        _ controller: TourController,
        steps: [TourStep],
        @ViewBuilder stepCard: @escaping (TourStepContext) -> StepCard
    ) -> some View {
        modifier(TourHostModifier(controller: controller, steps: steps,
                                  stepCard: { AnyView(stepCard($0)) }))
    }
}

private struct TourHostModifier: ViewModifier {
    @Environment(\.theme) private var theme

    // `@ObservedObject` (caller-owned instance): start/next/prev/stop mutate
    // `@Published` state, and this re-runs the overlay body (ADR-0007 §D3).
    @ObservedObject var controller: TourController
    let steps: [TourStep]
    /// When set, replaces the built-in card interior (custom content slot).
    var stepCard: ((TourStepContext) -> AnyView)? = nil

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(TourAnchorKey.self) { anchors in
            if controller.isActive, steps.indices.contains(controller.index) {
                GeometryReader { proxy in
                    let step = steps[controller.index]
                    let rect = anchors[step.id].map { proxy[$0] }
                    ZStack {
                        // Standard backdrop token strength (was a hand-rolled
                        // 0.6 dim — converged on the shared scrim, ADR-6).
                        Backdrop {
                            if let rect {
                                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                                    .frame(width: rect.width + 12, height: rect.height + 12)
                                    .position(x: rect.midX, y: rect.midY)
                            }
                        }
                        .onTapGesture { controller.stop() }

                        if let rect {
                            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                                .stroke(theme.background(.bgHero), lineWidth: 2)
                                .frame(width: rect.width + 12, height: rect.height + 12)
                                .position(x: rect.midX, y: rect.midY)
                        }

                        card(step: step, rect: rect, proxy: proxy)
                    }
                }
            }
        }
    }

    private func card(step: TourStep, rect: CGRect?, proxy: GeometryProxy) -> some View {
        let belowY = (rect?.maxY ?? proxy.size.height / 2) + 90
        let fitsBelow = belowY < proxy.size.height - 40
        let y = rect == nil ? proxy.size.height / 2 : (fitsBelow ? (rect!.maxY + 90) : (rect!.minY - 90))

        return Group {
            if let stepCard {
                stepCard(TourStepContext(
                    step: step,
                    index: controller.index,
                    count: steps.count,
                    next: { controller.next(count: steps.count) },
                    prev: { controller.prev() },
                    skip: { controller.stop() }
                ))
            } else {
                defaultCardContent(step: step)
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(width: 280)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        .themeShadow(.elevated)
        .overlay(alignment: .topTrailing) {
            Button { controller.stop() } label: {
                Icon(systemName: "xmark").size(.xs).color(theme.text(.textTertiary)).padding(Theme.SpacingKey.sm.value)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(themeKit: "Close"))
        }
        .position(x: proxy.size.width / 2, y: max(90, min(y, proxy.size.height - 90)))
    }

    /// The built-in card interior: title / message plus progress and prev / next.
    private func defaultCardContent(step: TourStep) -> some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Text(step.title).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
            Text(step.message).textStyle(.bodyBase400).foregroundStyle(theme.text(.textSecondary))
            HStack {
                Text("\(controller.index + 1) / \(steps.count)")
                    .textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                Spacer()
                if controller.index > 0 {
                    ThemeButton(String(themeKit: "Back")) { controller.prev() }
                        .variant(.outline).size(.small)
                }
                ThemeButton(controller.index == steps.count - 1 ? String(themeKit: "Done") : String(themeKit: "Next")) {
                    controller.next(count: steps.count)
                }
                .size(.small)
            }
        }
    }
}

#Preview("Default step card") {
    // Overlay organism — the tour is pinned active (started at fixture
    // construction) so each matrix cell shows the presented spotlight + step
    // card as a single static frame; the idle host is the trivial state.
    let activeTour: TourController = {
        let controller = TourController()
        controller.start()
        return controller
    }()
    let idleTour = TourController()
    PreviewMatrix("Tour") {
        PreviewCase("Presented · spotlight + default step card") {
            VStack(spacing: 32) {
                PrimaryButton("Start tour") { activeTour.start() }
                    .tourTarget("start")
                OutlineButton("Search flights", action: {})
                    .tourTarget("search")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            .tourHost(activeTour, steps: [
                TourStep("start", title: "Welcome", message: "Kick off the guided tour from here."),
                TourStep("search", title: "Search", message: "Find flights, hotels and packages.")
            ])
        }
        PreviewCase("Idle host (tour not started)") {
            VStack(spacing: 32) {
                PrimaryButton("Start tour") { idleTour.start() }
                    .tourTarget("start")
                OutlineButton("Search flights", action: {})
                    .tourTarget("search")
            }
            .frame(maxWidth: .infinity)
            .tourHost(idleTour, steps: [
                TourStep("start", title: "Welcome", message: "Kick off the guided tour from here.")
            ])
        }
    }
}

#Preview("Custom step card") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @StateObject private var tour = TourController()
        var body: some View {
            VStack(spacing: 32) {
                PrimaryButton("Start tour") { tour.start() }
                    .tourTarget("start")
                OutlineButton("Favorites", action: {})
                    .tourTarget("favorites")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tourHost(tour, steps: [
                TourStep("start", title: "Welcome", message: "The card interior is fully custom here."),
                TourStep("favorites", title: "Favorites", message: "Save stays you love for later.")
            ]) { context in
                VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Icon(systemName: "lightbulb.fill").size(.md).color(theme.foreground(.fgHero))
                        Text(context.step.title).textStyle(.headingSm)
                            .foregroundStyle(theme.text(.textPrimary))
                    }
                    Text(context.step.message).textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                    ProgressBar(value: Double(context.index + 1) / Double(context.count))
                    HStack {
                        ThemeButton("Skip") { context.skip() }.variant(.outline).size(.small)
                        Spacer()
                        ThemeButton(context.index == context.count - 1 ? "Finish" : "Continue") {
                            context.next()
                        }
                        .size(.small)
                    }
                }
            }
        }
    }
    return Demo()
}
