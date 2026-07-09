//
//  DesignSpecResolver.swift
//  ThemeKit
//  Created by İsa Mercan on 30.06.2026.
//
//  The optional LLM/MCP path. The core ships ONLY this protocol + a closure
//  adapter — no networking, no LLM client (the core stays zero-dependency and
//  network-free). A host (e.g. the Demo) injects a resolver that routes the raw
//  `design.md` to an LLM / the MCP and returns a richer `DesignParseResult`. When
//  it throws or returns nil, the caller falls back to the heuristic parser.
//

import Foundation

/// Host-implemented bridge from a free-form `design.md` to a `ThemeConfig`.
public protocol DesignSpecResolving: Sendable {
    /// - Parameters:
    ///   - markdown: the raw design document.
    ///   - seed: defaults for fields the resolver can't determine.
    /// - Returns: a parsed result; throwing → the caller uses the heuristic instead.
    func resolve(_ markdown: String, seed: ThemeConfig) async throws -> DesignParseResult
}

/// Wraps a closure as a `DesignSpecResolving`, so a host can plug in an LLM/MCP
/// call without declaring a new type.
public struct ClosureDesignResolver: DesignSpecResolving, Sendable {
    private let body: @Sendable (String, ThemeConfig) async throws -> DesignParseResult

    public init(_ body: @escaping @Sendable (String, ThemeConfig) async throws -> DesignParseResult) {
        self.body = body
    }

    public func resolve(_ markdown: String, seed: ThemeConfig) async throws -> DesignParseResult {
        try await body(markdown, seed)
    }
}
