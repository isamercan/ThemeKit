//
//  InfoMessage.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  The pure value a validator produces: a typed message (text + severity +
//  optional links / custom icon). UI-independent (Foundation only) — the SwiftUI
//  color mapping and the `InfoMessageList` renderer live in `InfoMessageUI.swift`.
//

import Foundation

/// A typed message shown under a field (error / warning / success / info).
public struct InfoMessage: Identifiable, Equatable {
    public enum Kind: Int, Comparable {
        case info, success, warning, error
        public static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }

        /// Default SF Symbol for this severity (UI-independent — a symbol name).
        var systemImage: String? {
            switch self {
            case .info: return nil
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "exclamationmark.circle.fill"
            }
        }
    }

    public let id = UUID()
    public let text: String
    public let kind: Kind
    /// Tappable substrings inside `text` (reference `clickableParts` + action).
    public let links: [(substring: String, action: () -> Void)]
    /// Optional custom leading icon overriding the kind's default symbol.
    public let systemImage: String?

    public init(_ text: String, kind: Kind = .info, links: [(substring: String, action: () -> Void)] = [], systemImage: String? = nil) {
        self.text = text
        self.kind = kind
        self.links = links
        self.systemImage = systemImage
    }

    /// The icon to render: the custom override if set, else the kind's default.
    var resolvedSystemImage: String? { systemImage ?? kind.systemImage }

    public static func == (a: InfoMessage, b: InfoMessage) -> Bool { a.text == b.text && a.kind == b.kind }
}

public extension Array where Element == InfoMessage {
    /// The most severe kind present (drives border/label color).
    var dominantKind: InfoMessage.Kind? { map(\.kind).max() }
}
