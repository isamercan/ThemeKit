//
//  InlineText.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. Body text with tappable inline links. Improves on the reference
/// UnderlineText by using AttributedString + openURL routing instead of manual
/// NSRange math.
public struct InlineText: View {
    private let text: String
    private let links: [(substring: String, action: () -> Void)]
    private let baseColor: Color?
    private let style: TextStyle

    public init(_ text: String, links: [(substring: String, action: () -> Void)] = [],
                baseColor: Color? = nil, style: TextStyle = .bodySm400) {
        self.text = text
        self.links = links
        self.baseColor = baseColor
        self.style = style
    }

    public var body: some View {
        Text(attributed)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "inline",
                      let index = Int(url.absoluteString.replacingOccurrences(of: "inline:", with: "")),
                      links.indices.contains(index) else { return .systemAction }
                links[index].action()
                return .handled
            })
    }

    private var attributed: AttributedString {
        var string = AttributedString(text)
        string.font = style.font
        string.foregroundColor = baseColor ?? Theme.shared.text(.textSecondary)
        for (index, link) in links.enumerated() {
            if let range = string.range(of: link.substring) {
                string[range].foregroundColor = Theme.shared.text(.textHero)
                string[range].underlineStyle = .single
                string[range].link = URL(string: "inline:\(index)")
            }
        }
        return string
    }
}

#Preview {
    InlineText("By continuing you accept the Terms and the Privacy Policy.",
               links: [("Terms", { print("terms") }), ("Privacy Policy", { print("privacy") })])
        .padding()
}
