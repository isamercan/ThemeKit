//
//  CompatNavigationStack.swift
//  Demo
//
//  iOS 15.6 floor (ADR-0007): `NavigationStack` is iOS 16-only, so the Demo's
//  simple (non-path) navigation containers route through this shim — the real
//  `NavigationStack` on 16+, a stack-style `NavigationView` on 15. Screens that
//  need *programmatic* pushes (CatalogView's `-openDemo` deep-link) use a hidden
//  `NavigationLink(isActive:)` instead, which works on both.
//

import SwiftUI

struct CompatNavigationStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }
        } else {
            NavigationView { content }
                .navigationViewStyle(.stack)
        }
    }
}
