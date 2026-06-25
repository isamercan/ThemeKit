//
//  TypographyView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI
import ThemeKit

struct TypographyView: View {
    private let groups: [(String, [TextStyle])] = [
        ("Display", [.displaySm, .displayBase, .displayMd, .displayLg]),
        ("Heading", [.heading3xs, .heading2xs, .headingXs, .headingSm, .headingBase, .headingMd, .headingLg, .headingXl, .heading2xl]),
        ("Label", [.labelSm600, .labelBase600, .labelMd600, .labelLg600, .labelLg700]),
        ("Body", [.bodySm400, .bodyBase400, .bodyMd400, .bodyLg400, .bodyLg500]),
        ("Overline", [.overline400, .overline500]),
        ("Link", [.linkSm, .linkBase, .linkMd]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(groups, id: \.0) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.0).textStyle(.headingSm)
                                .foregroundStyle(.secondary)
                            ForEach(group.1, id: \.self) { style in
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Montserrat").textStyle(style)
                                    Spacer()
                                    Text(label(for: style))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                DividerView(size: .small)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Typography")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ThemeSwitcherMenu() } }
        }
    }

    private func label(for style: TextStyle) -> String {
        let spec = style.spec
        return "\(Int(spec.size))/\(Int(spec.lineHeight))"
    }
}

#Preview {
    TypographyView()
        .environmentObject(Theme.shared)
        .environmentObject(DemoThemeStore())
}
