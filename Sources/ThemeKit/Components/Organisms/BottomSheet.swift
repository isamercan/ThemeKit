//
//  BottomSheet.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Presents content in a bottom sheet with detents + drag indicator
//  (native sheet under the hood). Two entry points:
//    • `.bottomSheet(isPresented:detents:)` — declarative, binding-driven.
//    • `.sheetHost()` + `@EnvironmentObject var sheet: SheetPresenter` —
//      imperative; present a sheet from anywhere without owning a binding.
//  Both paths support a `detached` floating-card presentation (HeroUI parity),
//  a `surface` background-token override, and a `radius` corner-role override.
//  Detent + corner-radius modifiers are iOS-only; the content still presents on macOS.
//

import SwiftUI

/// A sheet snap point. Maps to the native `PresentationDetent`, plus absolute
/// `height` and screen-`fraction` detents for fully custom sheets.
public enum BottomSheetDetent: Hashable {
    case medium
    case large
    case height(CGFloat)
    case fraction(Double)

    var presentationDetent: PresentationDetent {
        switch self {
        case .medium: return .medium
        case .large: return .large
        case .height(let h): return .height(h)
        case .fraction(let f): return .fraction(f)
        }
    }
}

public extension View {
    /// Declarative bottom sheet. Pass custom `detents` (default medium + large)
    /// and toggle the drag indicator.
    ///
    /// - Parameters:
    ///   - detached: When `true`, presents as an inset floating card — the native
    ///     sheet background goes clear and the content is wrapped in a
    ///     token-rounded card padded from the screen edges (HeroUI "detached").
    ///   - surface: Background token for the sheet surface (card fill when
    ///     `detached`). `nil` keeps the platform default (or `.bgWhite` for the
    ///     detached card).
    ///   - radius: Corner role for the sheet (card corner when `detached`).
    ///     `nil` keeps the platform default (or `.box` for the detached card).
    func bottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        detents: [BottomSheetDetent] = [.medium, .large],
        showsDragIndicator: Bool = true,
        detached: Bool = false,
        surface: Theme.BackgroundColorKey? = nil,
        radius: Theme.RadiusRole? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .padding(Theme.SpacingKey.md.value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sheetDetents(detents, dragIndicator: showsDragIndicator)
                .modifier(SheetChrome(detached: detached, surface: surface, radius: radius))
        }
    }
}

// MARK: - Imperative presenter

/// Imperative bottom-sheet presenter. Install once with `.sheetHost()`, then from
/// any descendant view:
///
///     @EnvironmentObject var sheet: SheetPresenter
///     sheet.present(detents: [.height(280), .large]) { FilterView() }
///     sheet.dismiss()
///
/// > Important: iOS 15.6-floor migration (ADR-0007 §D4). `SheetPresenter` is an
/// > `ObservableObject` (the iOS-17 `@Observable` pattern no longer applies):
/// > read it with `@EnvironmentObject` — `@Environment(SheetPresenter.self)`
/// > will not compile — and if you own an instance yourself, hold it as
/// > `@StateObject` (NOT `@State`: with `@State` it still compiles but views
/// > silently stop updating).
public final class SheetPresenter: ObservableObject {

    struct Request: Identifiable {
        let id = UUID()
        let detents: [BottomSheetDetent]
        let showsDragIndicator: Bool
        let detached: Bool
        let surface: Theme.BackgroundColorKey?
        let radius: Theme.RadiusRole?
        let content: AnyView
    }

    @Published var current: Request?

    public init() {}

    /// Present a sheet. Replaces any visible sheet. `detached` floats the sheet
    /// as an inset card; `surface`/`radius` override the sheet background token
    /// and corner role (see `bottomSheet(isPresented:…)`).
    public func present<C: View>(
        detents: [BottomSheetDetent] = [.medium, .large],
        showsDragIndicator: Bool = true,
        detached: Bool = false,
        surface: Theme.BackgroundColorKey? = nil,
        radius: Theme.RadiusRole? = nil,
        @ViewBuilder _ content: () -> C
    ) {
        current = Request(
            detents: detents,
            showsDragIndicator: showsDragIndicator,
            detached: detached,
            surface: surface,
            radius: radius,
            content: AnyView(content())
        )
    }

    public func dismiss() { current = nil }

    public var isPresented: Bool { current != nil }
}

private struct SheetHostModifier: ViewModifier {
    @StateObject private var presenter = SheetPresenter()

    func body(content: Content) -> some View {
        content
            .environmentObject(presenter)
            .sheet(item: $presenter.current) { request in
                request.content
                    .padding(Theme.SpacingKey.md.value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sheetDetents(request.detents, dragIndicator: request.showsDragIndicator)
                    .modifier(SheetChrome(detached: request.detached, surface: request.surface, radius: request.radius))
            }
    }
}

public extension View {
    /// Installs the shared `SheetPresenter`. Apply once near the app root, above
    /// any view that calls `sheet.present(…)`.
    func sheetHost() -> some View {
        modifier(SheetHostModifier())
    }
}

private extension View {
    @ViewBuilder
    func sheetDetents(_ detents: [BottomSheetDetent], dragIndicator: Bool) -> some View {
        #if os(iOS)
        self
            .presentationDetents(Set(detents.map(\.presentationDetent)))
            .presentationDragIndicator(dragIndicator ? .visible : .hidden)
        #else
        self
        #endif
    }
}

/// Presentation chrome shared by both entry points: detached floating-card mode,
/// surface-token background, and radius-role corner.
/// `presentationBackground` is iOS 16.4+ / macOS 13.3+ — inside our iOS 17 /
/// macOS 14 floor, so no gating; `presentationCornerRadius` is unavailable on
/// macOS, hence the `#if os(iOS)`.
private struct SheetChrome: ViewModifier {
    @Environment(\.theme) private var theme

    let detached: Bool
    let surface: Theme.BackgroundColorKey?
    let radius: Theme.RadiusRole?

    @ViewBuilder
    func body(content: Content) -> some View {
        if detached {
            content
                .background(
                    theme.background(surface ?? .bgWhite),
                    in: RoundedRectangle(cornerRadius: (radius ?? .box).value, style: .continuous)
                )
                .padding(Theme.SpacingKey.md.value)
                .presentationBackground(.clear)
        } else {
            attached(content)
        }
    }

    @ViewBuilder
    private func attached(_ content: Content) -> some View {
        let surfaced = Group {
            if let surface {
                content.presentationBackground(theme.background(surface))
            } else {
                content
            }
        }
        #if os(iOS)
        if let radius {
            surfaced.presentationCornerRadius(radius.value)
        } else {
            surfaced
        }
        #else
        surfaced
        #endif
    }
}

#Preview("Declarative") {
    struct Demo: View {
        @State var show = false
        var body: some View {
            PrimaryButton("Open sheet") { show = true }
                .padding()
                .bottomSheet(isPresented: $show, detents: [.height(260), .large]) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filters").textStyle(.headingSm)
                        Text("Sheet content goes here.").textStyle(.bodyBase400)
                    }
                }
        }
    }
    return Demo()
}

#Preview("Imperative host") {
    struct Demo: View {
        @EnvironmentObject var sheet: SheetPresenter
        var body: some View {
            PrimaryButton("Present") {
                sheet.present(detents: [.medium, .large]) {
                    Text("Imperative sheet").textStyle(.headingSm)
                }
            }
            .padding()
        }
    }
    return Demo().sheetHost()
}

#Preview("Detached card") {
    struct Demo: View {
        @State var show = false
        var body: some View {
            PrimaryButton("Open detached sheet") { show = true }
                .padding()
                .bottomSheet(isPresented: $show, detents: [.height(220)], detached: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detached").textStyle(.headingSm)
                        Text("Floats above the bottom edge as an inset card.").textStyle(.bodyBase400)
                    }
                }
        }
    }
    return Demo()
}

#Preview("Tinted surface + custom radius") {
    struct Demo: View {
        @EnvironmentObject var sheet: SheetPresenter
        @State var showTinted = false
        var body: some View {
            VStack(spacing: 12) {
                PrimaryButton("Tinted surface") { showTinted = true }
                PrimaryButton("Custom radius (imperative)") {
                    sheet.present(detents: [.medium], radius: .field) {
                        Text("Field-radius corners").textStyle(.headingSm)
                    }
                }
            }
            .padding()
            .bottomSheet(isPresented: $showTinted, detents: [.medium], surface: .bgSecondaryLight, radius: .box) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tinted").textStyle(.headingSm)
                    Text("Sheet surface uses a background token.").textStyle(.bodyBase400)
                }
            }
        }
    }
    return Demo().sheetHost()
}
