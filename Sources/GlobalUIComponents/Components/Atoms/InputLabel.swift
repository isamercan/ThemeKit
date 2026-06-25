//
//  InputLabel.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Atom. A form field label: text + optional required asterisk + optional info
//  glyph. Shared by the input components.
//

import SwiftUI

public struct InputLabel: View {
    private let text: String
    private let isRequired: Bool
    private let hasInfo: Bool
    private let hasError: Bool

    public init(_ text: String, isRequired: Bool = false, hasInfo: Bool = false, hasError: Bool = false) {
        self.text = text
        self.isRequired = isRequired
        self.hasInfo = hasInfo
        self.hasError = hasError
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .textStyle(.labelSm600)
                .foregroundStyle(hasError ? Theme.shared.foreground(.systemcolorsFgError) : Theme.shared.text(.textPrimary))
            if isRequired {
                Text("*").textStyle(.labelSm600).foregroundStyle(Theme.shared.foreground(.systemcolorsFgError))
            }
            if hasInfo {
                Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(Theme.shared.text(.textTertiary))
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        InputLabel("Email")
        InputLabel("Password", isRequired: true, hasInfo: true)
        InputLabel("Invalid", hasError: true)
    }
    .padding()
}
