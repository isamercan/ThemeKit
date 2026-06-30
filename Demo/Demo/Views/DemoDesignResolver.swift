//
//  DemoDesignResolver.swift
//  Demo
//  Created by İsa Mercan on 30.06.2026.
//
//  The Demo's optional LLM path for Design Mode. ThemeKit's core ships only the
//  `DesignSpecResolving` protocol (no networking); this Demo type provides a
//  concrete resolver that calls the Anthropic Messages API to turn a free-form
//  `design.md` into a `ThemeConfig`. It's used only when an API key is present;
//  otherwise the app passes `nil` and `DesignMode.resolve` uses the on-device
//  heuristic parser.
//

import Foundation
import ThemeKit

enum DemoDesignResolver {
    /// A fast, inexpensive model is plenty for this structured-extraction task.
    static let model = "claude-haiku-4-5-20251001"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Builds a resolver for the given key, or `nil` when the key is blank (so the
    /// caller falls back to the heuristic parser).
    static func make(apiKey: String) -> DesignSpecResolving? {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return ClosureDesignResolver { markdown, seed in
            try await resolve(markdown: markdown, seed: seed, apiKey: key)
        }
    }

    private static func resolve(markdown: String, seed: ThemeConfig, apiKey: String) async throws -> DesignParseResult {
        let system = """
        You convert a free-form design document into a ThemeKit ThemeConfig.
        Respond with ONLY a JSON object, no prose, with these keys:
        primaryHex (6-digit RRGGBB, no #), baseHex, secondaryHex, accentHex (all optional RRGGBB),
        tint (0..0.25), dark (bool), font (one of "Montserrat","System","SystemRounded","SystemSerif","SystemMono"),
        fontScale, radiusScale, spacingScale, shadowScale (positive multipliers near 1.0).
        Infer every value from the document's described look and feel.
        """
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "system": system,
            "messages": [["role": "user", "content": markdown]],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ResolverError.status(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let text = try extractText(from: data)
        let json = try extractJSONObject(from: text)
        let config = try JSONDecoder().decode(ThemeConfig.self, from: Data(json.utf8))

        return DesignParseResult(
            config: config,
            confidence: .high,
            method: .resolver("claude"),
            extracted: extractedFields(config),
            warnings: []
        )
    }

    // MARK: - Response parsing

    private static func extractText(from data: Data) throws -> String {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]] else {
            throw ResolverError.malformed
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw ResolverError.malformed }
        return text
    }

    /// Pulls the first JSON object out of the model's reply (tolerates code fences).
    private static func extractJSONObject(from text: String) throws -> String {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            throw ResolverError.malformed
        }
        return String(text[start...end])
    }

    private static func extractedFields(_ cfg: ThemeConfig) -> [DesignParseResult.Field: String] {
        var e: [DesignParseResult.Field: String] = [
            .primary: "#\(cfg.primaryHex)",
            .tint: String(format: "%.2f", cfg.tint),
            .dark: "\(cfg.dark)",
            .font: cfg.font,
            .radiusScale: String(format: "%.2f", cfg.radiusScale),
            .spacingScale: String(format: "%.2f", cfg.spacingScale),
            .shadowScale: String(format: "%.2f", cfg.shadowScale),
        ]
        if let b = cfg.baseHex { e[.base] = "#\(b)" }
        if let s = cfg.secondaryHex { e[.secondary] = "#\(s)" }
        if let a = cfg.accentHex { e[.accent] = "#\(a)" }
        return e
    }

    enum ResolverError: LocalizedError {
        case status(Int, String)
        case malformed

        var errorDescription: String? {
            switch self {
            case .status(let code, _): return "Anthropic API returned status \(code)."
            case .malformed: return "Could not read a ThemeConfig from the model's response."
            }
        }
    }
}
