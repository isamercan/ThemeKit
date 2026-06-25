//
//  Tour.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Guided product tour: spotlights a target view through a dimmed scrim and
//  shows a step card with prev / next / skip. (Ant Tour.)
//
//  Usage:
//      @StateObject var tour = TourController()
//      someView.tourTarget("search")
//      rootView.tourHost(tour, steps: [TourStep("search", title: "Search", message: "…")])
//      tour.start()
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

public extension View {
    /// Marks this view as a tour target with `id` (referenced by a `TourStep`).
    func tourTarget(_ id: String) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [id: $0] }
    }

    /// Hosts the tour overlay. Apply at the root that contains the targets.
    func tourHost(_ controller: TourController, steps: [TourStep]) -> some View {
        modifier(TourHostModifier(controller: controller, steps: steps))
    }

    fileprivate func reverseMask<M: View>(@ViewBuilder _ mask: () -> M) -> some View {
        self.mask { Rectangle().overlay { mask().blendMode(.destinationOut) } }
    }
}

private struct TourHostModifier: ViewModifier {
    @ObservedObject var controller: TourController
    let steps: [TourStep]

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(TourAnchorKey.self) { anchors in
            if controller.isActive, steps.indices.contains(controller.index) {
                GeometryReader { proxy in
                    let step = steps[controller.index]
                    let rect = anchors[step.id].map { proxy[$0] }
                    ZStack {
                        Theme.shared.background(.bgTertiary).opacity(0.6)
                            .reverseMask {
                                if let rect {
                                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                                        .frame(width: rect.width + 12, height: rect.height + 12)
                                        .position(x: rect.midX, y: rect.midY)
                                }
                            }
                            .ignoresSafeArea()
                            .onTapGesture { controller.stop() }

                        if let rect {
                            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                                .stroke(Theme.shared.background(.bgHero), lineWidth: 2)
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

        return VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Text(step.title).textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
            Text(step.message).textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textSecondary))
            HStack {
                Text("\(controller.index + 1) / \(steps.count)")
                    .textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textTertiary))
                Spacer()
                if controller.index > 0 {
                    ThemeButton(String(themeKit: "Back"), variant: .outline, size: .small) { controller.prev() }
                }
                ThemeButton(controller.index == steps.count - 1 ? String(themeKit: "Done") : String(themeKit: "Next"), size: .small) {
                    controller.next(count: steps.count)
                }
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(width: 280)
        .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        .themeShadow(.elevated)
        .overlay(alignment: .topTrailing) {
            Button { controller.stop() } label: {
                Icon(systemName: "xmark", size: .xs, color: Theme.shared.text(.textTertiary)).padding(Theme.SpacingKey.sm.value)
            }
            .buttonStyle(.plain)
        }
        .position(x: proxy.size.width / 2, y: max(90, min(y, proxy.size.height - 90)))
    }
}
