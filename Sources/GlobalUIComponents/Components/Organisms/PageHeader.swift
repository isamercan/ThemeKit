//
//  PageHeader.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Screen header: optional back button, title + subtitle, trailing
//  icon actions.
//

import SwiftUI

public struct PageHeader: View {
    public struct Action: Identifiable {
        public let id = UUID()
        let systemImage: String
        let handler: () -> Void
        public init(systemImage: String, handler: @escaping () -> Void) {
            self.systemImage = systemImage
            self.handler = handler
        }
    }

    private let title: String
    private let subtitle: String?
    private let onBack: (() -> Void)?
    private let actions: [Action]

    public init(
        _ title: String,
        subtitle: String? = nil,
        onBack: (() -> Void)? = nil,
        actions: [Action] = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.actions = actions
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let onBack {
                Button(action: onBack) {
                    Icon(systemName: "chevron.left", size: .md, color: Theme.shared.text(.textPrimary))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(.headingSm)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.bodySm400)
                        .foregroundStyle(Theme.shared.text(.textSecondary))
                }
            }

            Spacer(minLength: Theme.SpacingKey.sm.value)

            ForEach(actions) { action in
                Button(action: action.handler) {
                    Icon(systemName: action.systemImage, size: .md, color: Theme.shared.text(.textPrimary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }
}

#Preview {
    VStack(spacing: 16) {
        PageHeader("Search results", subtitle: "128 hotels", onBack: {},
                   actions: [.init(systemImage: "slider.horizontal.3", handler: {}),
                             .init(systemImage: "heart", handler: {})])
        PageHeader("Settings")
    }
    .padding()
}
