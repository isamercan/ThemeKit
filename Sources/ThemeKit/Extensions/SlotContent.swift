//
//  SlotContent.swift
//  ThemeKit
//
//  The single blessed store for an *optional* slot (ADR-2, slot convention):
//  required content stays a generic `@ViewBuilder` init parameter (type-
//  preserved); optional slots are copy-on-write modifiers that capture their
//  content into a `SlotContent?` — type-erased, `nil` = "use the built-in".
//
//  `SlotContent` is itself a `View`, so an adopter both stores and renders it
//  directly:
//
//      private var customHeader: SlotContent?            // nil → built-in header
//
//      func header<H: View>(@ViewBuilder _ header: () -> H) -> Self {
//          copy { $0.customHeader = SlotContent(header) }
//      }
//
//      // body:
//      if let customHeader { customHeader } else { titleHeader }
//
//  Identity note: `AnyView` diffs by the *wrapped* concrete type, so slot
//  content keeps `@State`/transitions as long as its type is stable across
//  parent re-renders. Call sites that alternate two different view types
//  directly in a slot should wrap them in `.id(_:)` — see the slot-type-
//  stability rule in the authoring skill.
//

import SwiftUI

/// Type-erased content of an optional slot; `nil` (no `SlotContent`) means
/// "render the component's built-in". Internal by design — the public surface
/// is each component's `@ViewBuilder` slot modifier, never `AnyView`.
struct SlotContent: View {
    private let content: AnyView

    /// Erases the slot's content. The closure is evaluated immediately at the
    /// modifier call site (during the parent's body construction), so nothing
    /// escapes and no `sending` is needed.
    init<V: View>(@ViewBuilder _ content: () -> V) {
        self.content = AnyView(content())
    }

    var body: some View { content }
}
