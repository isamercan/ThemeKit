//
//  TextLink.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Atom. A standalone tappable text link. (daisyUI "Link"; for links inside a
//  paragraph use InlineText, for a button use LinkButton.)
//

import SwiftUI

public struct TextLink: View {
    private let title: String
    private let underline: Bool
    private let action: () -> Void

    public init(_ title: String, underline: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.underline = underline
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(.linkBase)
                .underline(underline)
                .foregroundStyle(Theme.shared.text(.textHero))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        TextLink("Forgot password?") {}
        TextLink("Learn more", underline: false) {}
    }
    .padding()
}
