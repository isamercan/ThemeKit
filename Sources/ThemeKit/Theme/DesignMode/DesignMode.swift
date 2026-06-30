//
//  DesignMode.swift
//  ThemeKit
//  Created by İsa Mercan on 30.06.2026.
//
//  The public façade for Design Mode: parse a `design.md` into a `ThemeConfig`
//  (heuristic, or resolver-with-fallback) and apply it — which re-skins every
//  component through the existing `Theme.apply(_:)`.
//
//  Typical flow:
//    let spec   = try DesignSpecCatalog.load(fileURL: pickedURL)
//    let result = await DesignMode.resolve(spec, seed: currentConfig, using: myResolver)
//    // …show result.extracted / result.warnings for confirmation…
//    DesignMode.apply(result)         // @MainActor — re-skins all components
//

import SwiftUI

public enum DesignMode {

    /// Heuristic-only parse — synchronous, offline, always returns a config.
    public static func parse(
        _ spec: DesignSpec,
        seed: ThemeConfig = .default,
        parser: DesignMarkdownParsing = HeuristicDesignParser()
    ) -> DesignParseResult {
        parser.parse(spec.rawMarkdown, seed: seed)
    }

    /// Resolver-first parse with a guaranteed heuristic fallback. Never throws —
    /// if `resolver` is nil, throws, or fails, the heuristic result is returned.
    public static func resolve(
        _ spec: DesignSpec,
        seed: ThemeConfig = .default,
        using resolver: DesignSpecResolving?,
        parser: DesignMarkdownParsing = HeuristicDesignParser()
    ) async -> DesignParseResult {
        if let resolver {
            do {
                return try await resolver.resolve(spec.rawMarkdown, seed: seed)
            } catch {
                var fallback = parser.parse(spec.rawMarkdown, seed: seed)
                fallback.warnings.insert(
                    "AI resolver failed (\(error.localizedDescription)) — parsed on-device instead.",
                    at: 0
                )
                return fallback
            }
        }
        return parser.parse(spec.rawMarkdown, seed: seed)
    }

    /// Applies a parsed result to `theme` — re-skinning every component. Main-actor
    /// confined because `Theme` is applied from the main thread.
    @MainActor
    public static func apply(_ result: DesignParseResult, to theme: Theme = .shared) {
        theme.apply(result.config)
    }
}
