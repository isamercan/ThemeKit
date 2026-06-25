//
//  Tag.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Atom. A compact label, optionally removable. Distinct from Badge (status) and
//  Chip (selectable): Tag represents an applied keyword/filter.
//

import SwiftUI

public struct Tag: View {
    private let text: String
    private let leadingSystemImage: String?
    private let onRemove: (() -> Void)?

    public init(_ text: String, leadingSystemImage: String? = nil, onRemove: (() -> Void)? = nil) {
        self.text = text
        self.leadingSystemImage = leadingSystemImage
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let leadingSystemImage {
                Image(systemName: leadingSystemImage).font(.system(size: 12))
            }
            Text(text).textStyle(.labelSm600)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Theme.shared.text(.textHero))
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .frame(height: 28)
        .background(Theme.shared.background(.bgElevatorTertiary), in: Capsule())
    }
}

#Preview {
    HStack {
        Tag("İstanbul", onRemove: {})
        Tag("Beach", leadingSystemImage: "beach.umbrella")
        Tag("5 stars")
    }
    .padding()
}
