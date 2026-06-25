//
//  Breadcrumbs.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. Horizontal navigation path with chevron separators; the last crumb
//  is the current page. (daisyUI "Breadcrumbs".)
//

import SwiftUI

public struct Breadcrumbs: View {
    public struct Crumb: Identifiable {
        public let id = UUID()
        let title: String
        let action: (() -> Void)?
        public init(_ title: String, action: (() -> Void)? = nil) { self.title = title; self.action = action }
    }

    private let crumbs: [Crumb]

    public init(_ crumbs: [Crumb]) { self.crumbs = crumbs }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                ForEach(Array(crumbs.enumerated()), id: \.element.id) { index, crumb in
                    let isLast = index == crumbs.count - 1
                    Button { crumb.action?() } label: {
                        Text(crumb.title)
                            .textStyle(isLast ? .labelSm700 : .labelSm600)
                            .foregroundStyle(isLast ? Theme.shared.text(.textPrimary) : Theme.shared.text(.textHero))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLast || crumb.action == nil)

                    if !isLast {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.shared.text(.textTertiary))
                            .mirrorsInRTL()
                    }
                }
            }
        }
    }
}

#Preview {
    Breadcrumbs([.init("Home", action: {}), .init("Hotels", action: {}), .init("İstanbul", action: {}), .init("Grand Hotel")])
        .padding()
}
