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

    // `PresentationDetent` is iOS 16-only; below 16 the sheet presents
    // full-height through the named `LegacySheetDetentChrome` unit instead.
    @available(iOS 16.0, *)
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
        bottomSheet(isPresented: isPresented,
                    detents: detents,
                    showsDragIndicator: showsDragIndicator,
                    detached: detached,
                    surface: surface,
                    radius: radius,
                    contentPadding: nil,
                    content: content)
    }

    /// Declarative bottom sheet with the content inset spelled out.
    ///
    /// The same sheet as `bottomSheet(isPresented:detents:showsDragIndicator:detached:surface:radius:content:)`,
    /// plus `contentPadding`. It is a separate overload rather than one more
    /// defaulted parameter on that one so the 1.7.0 signature survives
    /// untouched: inserting a parameter renames a function for the API
    /// digester, and this release is additive.
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
    ///   - contentPadding: The inset around the sheet's content. `nil` (the
    ///     default) keeps the stock `md` on all four sides; pass your own
    ///     `EdgeInsets` when the sheet brings its own padding — a header that
    ///     must run edge to edge, or a spec whose side and top insets differ.
    func bottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        detents: [BottomSheetDetent] = [.medium, .large],
        showsDragIndicator: Bool = true,
        detached: Bool = false,
        surface: Theme.BackgroundColorKey? = nil,
        radius: Theme.RadiusRole? = nil,
        contentPadding: EdgeInsets? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .padding(BottomSheetMetrics.contentPadding(contentPadding))
                .frame(maxWidth: .infinity, alignment: .leading)
                .sheetDetents(detents, dragIndicator: showsDragIndicator, detached: detached)
                .modifier(SheetChrome(detached: detached, surface: surface, radius: radius))
        }
    }
}

/// The sheet's fixed chrome metrics, shared by both entry points.
enum BottomSheetMetrics {
    /// The inset around a sheet's content: the caller's `contentPadding` when
    /// set, else the stock `md` on all four sides.
    static func contentPadding(_ insets: EdgeInsets?) -> EdgeInsets {
        if let insets { return insets }
        let md = Theme.SpacingKey.md.value
        return EdgeInsets(top: md, leading: md, bottom: md, trailing: md)
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
        let contentPadding: EdgeInsets?
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
        present(detents: detents,
                showsDragIndicator: showsDragIndicator,
                detached: detached,
                surface: surface,
                radius: radius,
                contentPadding: nil,
                content)
    }

    /// Present a sheet with the content inset spelled out — the same sheet as
    /// `present(detents:showsDragIndicator:detached:surface:radius:_:)`, plus
    /// `contentPadding` (`nil` keeps the stock `md` on all four sides). It is a
    /// separate overload for the same reason the declarative twin is: the
    /// 1.7.0 signature stays untouched.
    public func present<C: View>(
        detents: [BottomSheetDetent] = [.medium, .large],
        showsDragIndicator: Bool = true,
        detached: Bool = false,
        surface: Theme.BackgroundColorKey? = nil,
        radius: Theme.RadiusRole? = nil,
        contentPadding: EdgeInsets? = nil,
        @ViewBuilder _ content: () -> C
    ) {
        current = Request(
            detents: detents,
            showsDragIndicator: showsDragIndicator,
            detached: detached,
            surface: surface,
            radius: radius,
            contentPadding: contentPadding,
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
                    .padding(BottomSheetMetrics.contentPadding(request.contentPadding))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sheetDetents(request.detents, dragIndicator: request.showsDragIndicator, detached: request.detached)
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
    func sheetDetents(_ detents: [BottomSheetDetent], dragIndicator: Bool, detached: Bool = false) -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            self
                .presentationDetents(Set(detents.map(\.presentationDetent)))
                .presentationDragIndicator(dragIndicator ? .visible : .hidden)
        } else {
            modifier(LegacySheetDetentChrome(showsDragIndicator: dragIndicator, detached: detached))
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Named legacy unit (ADR-0007 §D2 rule 3): below iOS 16 there are no
/// presentation detents — the sheet presents at the system's full page height —
/// so the organism routes through its own chrome instead: attached content
/// top-aligns in the full-height sheet (a `detached` card keeps hugging its
/// content) and the drag-indicator capsule is drawn with kit tokens (the
/// system indicator is 16-only too). Shared by `BottomSheet` and `PhoneField`'s
/// searchable picker sheet.
struct LegacySheetDetentChrome: ViewModifier {
    @Environment(\.theme) private var theme

    let showsDragIndicator: Bool
    var detached: Bool = false

    /// The system drag-indicator footprint — fixed chrome constants.
    private static let indicatorSize = CGSize(width: 36, height: 5)

    func body(content: Content) -> some View {
        content
            .frame(maxHeight: detached ? nil : .infinity, alignment: .top)
            .overlay(alignment: .top) {
                if showsDragIndicator {
                    Capsule()
                        .fill(theme.border(.borderPrimary))
                        .frame(width: Self.indicatorSize.width, height: Self.indicatorSize.height)
                        .padding(.top, Theme.SpacingKey.xs.value)
                        .accessibilityHidden(true)   // decorative affordance
                }
            }
    }
}
#endif

/// Presentation chrome shared by both entry points: detached floating-card mode,
/// surface-token background, and radius-role corner.
/// `presentationBackground`/`presentationCornerRadius` are iOS 16.4+
/// (macOS 14 ≥ their macOS 13.3 floor, so `#available(iOS 16.4, *)` is
/// statically true there); below 16.4 each degrades through a named unit
/// drawn with the organism's own chrome (ADR-0007 §D2 rules 2–3).
/// `presentationCornerRadius` stays iOS-only (`#if os(iOS)` inside
/// ``SheetCornerRadiusCompat``) — it does not exist on macOS.
private struct SheetChrome: ViewModifier {
    @Environment(\.theme) private var theme

    let detached: Bool
    let surface: Theme.BackgroundColorKey?
    let radius: Theme.RadiusRole?

    @ViewBuilder
    func body(content: Content) -> some View {
        if detached {
            if #available(iOS 16.4, *) {
                detachedCard(content).presentationBackground(.clear)
            } else {
                content.modifier(LegacyDetachedSheetCard(surface: surface, radius: radius))
            }
        } else {
            attached(content)
        }
    }

    /// The floating-card chrome: token surface in a continuous-rounded card,
    /// inset from the sheet edges.
    private func detachedCard(_ content: Content) -> some View {
        content
            .background(
                theme.background(surface ?? .bgWhite),
                in: RoundedRectangle(cornerRadius: (radius ?? .box).value, style: .continuous)
            )
            .padding(Theme.SpacingKey.md.value)
    }

    @ViewBuilder
    private func attached(_ content: Content) -> some View {
        let surfaced = Group {
            if let surface {
                if #available(iOS 16.4, *) {
                    content.presentationBackground(theme.background(surface))
                } else {
                    content.modifier(LegacySheetSurface(surface: surface))
                }
            } else {
                content
            }
        }
        if let radius {
            surfaced.modifier(SheetCornerRadiusCompat(radius: radius))
        } else {
            surfaced
        }
    }
}

/// Named legacy unit (ADR-0007 §D2 rule 3): below iOS 16.4 there is no
/// `presentationBackground(.clear)`, so the detached card draws its own
/// token-rounded chrome while the system sheet backdrop behind it stays
/// opaque — the card still reads as an inset surface on its own sheet.
struct LegacyDetachedSheetCard: ViewModifier {
    @Environment(\.theme) private var theme

    let surface: Theme.BackgroundColorKey?
    let radius: Theme.RadiusRole?

    func body(content: Content) -> some View {
        content
            .background(
                theme.background(surface ?? .bgWhite),
                in: RoundedRectangle(cornerRadius: (radius ?? .box).value, style: .continuous)
            )
            .padding(Theme.SpacingKey.md.value)
    }
}

/// Named legacy unit (ADR-0007 §D2 rule 3): below iOS 16.4 the surface token
/// paints the sheet by filling the content's backdrop edge-to-edge instead of
/// `presentationBackground`.
struct LegacySheetSurface: ViewModifier {
    @Environment(\.theme) private var theme

    let surface: Theme.BackgroundColorKey

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background(surface).ignoresSafeArea())
    }
}

/// Named degrade unit (ADR-0007 §D2 rule 3) for `presentationCornerRadius`
/// (iOS 16.4; unavailable on macOS): native corner-role radius on 16.4+, the
/// system sheet corner below — pure polish.
struct SheetCornerRadiusCompat: ViewModifier {
    let radius: Theme.RadiusRole

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 16.4, *) {
            content.presentationCornerRadius(radius.value)
        } else {
            content
        }
        #else
        content
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
