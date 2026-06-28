//
//  Fieldset.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A bordered form group with a legend + optional helper text.
/// (daisyUI "Fieldset".)
public struct Fieldset<Content: View>: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let helper: String?
    private let content: () -> Content

    public init(_ title: String, helper: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.helper = helper
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Text(title)
                .textStyle(.labelBase700)
                .foregroundStyle(theme.text(.textPrimary))
            content()
            if let helper {
                Text(helper)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
    }
}

#Preview {
    struct Demo: View {
        @State var name = ""
        @State var subscribe = true
        var body: some View {
            Fieldset("Contact details", helper: "We'll only use this to confirm your booking.") {
                TextInput("Full name", text: $name)
                HStack { Checkbox(isChecked: $subscribe); Text("Subscribe to newsletter").textStyle(.bodyBase400); Spacer() }
            }
            .padding()
        }
    }
    return Demo()
}
