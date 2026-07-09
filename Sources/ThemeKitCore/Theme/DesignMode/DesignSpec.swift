//
//  DesignSpec.swift
//  ThemeKit
//  Created by İsa Mercan on 30.06.2026.
//
//  Design Mode — bring every component into a target look by importing another
//  app's free-form `design.md` (file / URL / bundled catalog) and turning it into
//  a `ThemeConfig`, then applying it with `Theme.shared.apply(_:)` (which already
//  re-skins all components). `DesignSpec` is the imported document; a parser /
//  resolver turns it into a `DesignParseResult` (an always-applicable config plus
//  the provenance the confirm UI shows).
//

import Foundation

/// An imported design document: a free-form markdown describing an app's look,
/// plus where it came from. Parsed into a `ThemeConfig` by `DesignMode`.
public struct DesignSpec: Identifiable, Equatable, Sendable {
    /// Stable slug, e.g. `"linear-dark"` (bundled filename) or a derived id.
    public let id: String
    /// Human title for the catalog card (first `#` heading or `title:` front-matter).
    public let title: String
    /// One-line description (first paragraph or `summary:` front-matter).
    public let summary: String?
    /// Where this spec was loaded from.
    public let source: Source
    /// The raw markdown — the parser/resolver's only input.
    public let rawMarkdown: String

    public enum Source: Equatable, Sendable {
        case bundled(resource: String)
        case file(URL)
        case remote(URL)
        case pasted
    }

    public init(id: String, title: String, summary: String? = nil,
                source: Source, rawMarkdown: String) {
        self.id = id
        self.title = title
        self.summary = summary
        self.source = source
        self.rawMarkdown = rawMarkdown
    }
}

/// The result of parsing a `DesignSpec`: an always-applicable `ThemeConfig` plus
/// how it was derived. `extracted` + `warnings` are what the confirm/preview UI
/// surfaces so the user sees what ambiguous free text became before committing.
public struct DesignParseResult: Equatable, Sendable {
    /// The portable recipe to apply via `Theme.apply(_:)`. Always present.
    public var config: ThemeConfig
    /// How confident we are in `config` (drives the UI badge).
    public var confidence: Confidence
    /// Which path produced `config`.
    public var method: Method
    /// Human-readable derived values, keyed by field — shown in the confirm step.
    public var extracted: [Field: String]
    /// Notes about defaults/fallbacks the parser had to make.
    public var warnings: [String]

    public enum Confidence: Int, Comparable, Sendable {
        case low, medium, high
        public static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
    }

    public enum Method: Equatable, Sendable {
        case heuristic
        case resolver(String)
    }

    /// The recipe fields a `design.md` can drive — used as keys in `extracted`.
    public enum Field: String, Sendable, CaseIterable {
        case primary, base, secondary, accent
        case tint, dark, font
        case radiusScale, spacingScale, fontScale, shadowScale
    }

    public init(config: ThemeConfig,
                confidence: Confidence = .low,
                method: Method = .heuristic,
                extracted: [Field: String] = [:],
                warnings: [String] = []) {
        self.config = config
        self.confidence = confidence
        self.method = method
        self.extracted = extracted
        self.warnings = warnings
    }
}
