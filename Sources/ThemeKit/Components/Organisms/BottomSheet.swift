//
//  BottomSheet.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Presents content in a bottom sheet with detents + drag indicator
//  (native sheet under the hood). Two entry points:
//    • `.bottomSheet(isPresented:detents:)` — declarative, binding-driven.
//    • `.sheetHost()` + `@Environment(SheetPresenter.self)` — imperative; present
//      a sheet from anywhere without owning a binding.
//  Detent modifiers are iOS-only; the content still presents on macOS.
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
    func bottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        detents: [BottomSheetDetent] = [.medium, .large],
        showsDragIndicator: Bool = true,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .padding(Theme.SpacingKey.md.value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sheetDetents(detents, dragIndicator: showsDragIndicator)
        }
    }
}

// MARK: - Imperative presenter

/// Imperative bottom-sheet presenter. Install once with `.sheetHost()`, then from
/// any descendant view:
///
///     @Environment(SheetPresenter.self) var sheet: SheetPresenter
///     sheet.present(detents: [.height(280), .large]) { FilterView() }
///     sheet.dismiss()
@Observable
public final class SheetPresenter {

    struct Request: Identifiable {
        let id = UUID()
        let detents: [BottomSheetDetent]
        let showsDragIndicator: Bool
        let content: AnyView
    }

    var current: Request?

    public init() {}

    /// Present a sheet. Replaces any visible sheet.
    public func present<C: View>(
        detents: [BottomSheetDetent] = [.medium, .large],
        showsDragIndicator: Bool = true,
        @ViewBuilder _ content: () -> C
    ) {
        current = Request(detents: detents, showsDragIndicator: showsDragIndicator, content: AnyView(content()))
    }

    public func dismiss() { current = nil }

    public var isPresented: Bool { current != nil }
}

private struct SheetHostModifier: ViewModifier {
    @State private var presenter = SheetPresenter()

    func body(content: Content) -> some View {
        content
            .environment(presenter)
            .sheet(item: $presenter.current) { request in
                request.content
                    .padding(Theme.SpacingKey.md.value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sheetDetents(request.detents, dragIndicator: request.showsDragIndicator)
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
        @Environment(SheetPresenter.self) var sheet: SheetPresenter
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
