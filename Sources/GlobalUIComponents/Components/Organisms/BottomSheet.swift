//
//  BottomSheet.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Presents content in a bottom sheet with detents + drag indicator
//  (native sheet under the hood). Detent modifiers are iOS-only.
//

import SwiftUI

public extension View {
    func bottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .padding(Theme.SpacingKey.md.value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sheetDetents()
        }
    }
}

private extension View {
    @ViewBuilder
    func sheetDetents() -> some View {
        #if os(iOS)
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
        self
        #endif
    }
}

#Preview {
    struct Demo: View {
        @State var show = false
        var body: some View {
            PrimaryButton("Open sheet") { show = true }
                .padding()
                .bottomSheet(isPresented: $show) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filters").textStyle(.headingSm)
                        Text("Sheet content goes here.").textStyle(.bodyBase400)
                    }
                }
        }
    }
    return Demo()
}
