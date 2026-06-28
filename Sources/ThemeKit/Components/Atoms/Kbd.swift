//
//  Kbd.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. A keyboard key cap. (daisyUI "Kbd".)
public struct Kbd: View {
    private let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced).weight(.semibold))
            .foregroundStyle(Theme.shared.text(.textPrimary))
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .frame(minWidth: 28, minHeight: 28)
            .background(Theme.shared.background(.bgElevatorPrimary),
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
                    .stroke(Theme.shared.border(.borderPrimary), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.shared.border(.borderPrimary))
                    .frame(height: 2)
                    .padding(.horizontal, 4)
                    .offset(y: 1)
            }
    }
}

#Preview {
    HStack(spacing: 6) {
        Kbd("⌘"); Kbd("K")
        Text("then").font(.caption).foregroundStyle(.secondary)
        Kbd("esc")
    }
    .padding()
}
