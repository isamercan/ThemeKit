//
//  Tooltip.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A small dark bubble with an arrow, attached above/below an anchor
//  via the `.tooltip(...)` modifier.
//

import SwiftUI

public enum TooltipEdge: Sendable {
    case top, bottom
}

private struct TooltipBubble: View {
    let text: String
    let edge: TooltipEdge

    var body: some View {
        VStack(spacing: -1) {
            if edge == .bottom { arrow.rotationEffect(.degrees(180)) }
            Text(text)
                .textStyle(.bodySm400)
                .foregroundStyle(Theme.shared.foreground(.fgSecondary))
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .padding(.vertical, Theme.SpacingKey.xs.value)
                .background(Theme.shared.background(.bgTertiary),
                           in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
            if edge == .top { arrow }
        }
    }

    private var arrow: some View {
        Triangle()
            .fill(Theme.shared.background(.bgTertiary))
            .frame(width: 12, height: 6)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

public extension View {
    func tooltip(_ text: String, isPresented: Binding<Bool>, edge: TooltipEdge = .top) -> some View {
        overlay(alignment: edge == .top ? .top : .bottom) {
            if isPresented.wrappedValue {
                TooltipBubble(text: text, edge: edge)
                    .fixedSize()
                    .offset(y: edge == .top ? -8 : 8)
                    .alignmentGuide(edge == .top ? .top : .bottom) { d in edge == .top ? d[.bottom] : d[.top] }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(Motion.fast.animation, value: isPresented.wrappedValue)
    }
}

#Preview {
    struct Demo: View {
        @State var show = true
        var body: some View {
            Icon(systemName: "info.circle", size: .md, color: Theme.shared.foreground(.fgHero))
                .tooltip("Helpful hint", isPresented: $show)
                .padding(60)
        }
    }
    return Demo()
}
