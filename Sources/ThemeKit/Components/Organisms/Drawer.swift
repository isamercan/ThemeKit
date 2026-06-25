//
//  Drawer.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A side drawer that slides in over a dimmed scrim, presented via the
//  `.drawer(...)` modifier. (daisyUI "Drawer".)
//

import SwiftUI

private struct DrawerModifier<DrawerContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let edge: HorizontalEdge
    let width: CGFloat
    let content: () -> DrawerContent

    func body(content base: Content) -> some View {
        base.overlay {
            if isPresented {
                ZStack(alignment: edge == .leading ? .leading : .trailing) {
                    Theme.shared.background(.bgTertiary).opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }

                    self.content()
                        .frame(maxWidth: width, maxHeight: .infinity, alignment: .topLeading)
                        .frame(maxHeight: .infinity)
                        .background(Theme.shared.background(.bgWhite))
                        .ignoresSafeArea()
                        .transition(.move(edge: edge == .leading ? .leading : .trailing))
                }
                .zIndex(1)
            }
        }
        .animation(Motion.base.animation, value: isPresented)
    }
}

public extension View {
    /// Presents `content` as a side drawer over a scrim.
    func drawer<DrawerContent: View>(
        isPresented: Binding<Bool>,
        edge: HorizontalEdge = .leading,
        width: CGFloat = 300,
        @ViewBuilder content: @escaping () -> DrawerContent
    ) -> some View {
        modifier(DrawerModifier(isPresented: isPresented, edge: edge, width: width, content: content))
    }
}

#Preview {
    struct Demo: View {
        @State private var open = false
        var body: some View {
            ZStack {
                PrimaryButton("Open drawer") { open = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .drawer(isPresented: $open) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Menu").textStyle(.headingSm)
                    ListRow("Account", leadingSystemImage: "person.circle", action: {})
                    ListRow("Settings", leadingSystemImage: "gearshape", action: {})
                    Spacer()
                }
                .padding()
                .padding(.top, 60)
            }
        }
    }
    return Demo()
}
