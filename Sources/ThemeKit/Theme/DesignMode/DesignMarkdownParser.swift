//
//  DesignMarkdownParser.swift
//  ThemeKit
//  Created by İsa Mercan on 30.06.2026.
//
//  Turns a free-form `design.md` into a `ThemeConfig`. The heuristic parser is
//  deterministic, offline and *total* — it always returns an applicable config
//  (seeded from `seed` so unspecified fields keep sensible defaults). It is the
//  floor under the optional LLM/MCP resolver (`DesignSpecResolving`).
//
//  Foundation-only (no SwiftUI): pure string work, fully unit-testable.
//

import Foundation

/// Parses a markdown design document into a `ThemeConfig` + provenance.
public protocol DesignMarkdownParsing: Sendable {
    /// - Parameters:
    ///   - markdown: the raw `design.md` text.
    ///   - seed: defaults for fields the document doesn't specify.
    func parse(_ markdown: String, seed: ThemeConfig) -> DesignParseResult
}

public extension DesignMarkdownParsing {
    func parse(_ markdown: String) -> DesignParseResult { parse(markdown, seed: .default) }
}

/// A dependency-free, deterministic parser. Extraction order (each step only
/// overwrites a field when it finds a value, starting from `seed`):
/// 1. An explicit structured block (` ```themekit ` / ` ```json ` / `---` front-matter)
///    of `key: value` pairs wins outright → high confidence.
/// 2. Label-aware hex colors (primary / base / secondary / accent).
/// 3. Light/dark keywords, with a fallback inference from the base color's luminance.
/// 4. Roundedness / density / font / shadow / tint keyword cues → scale knobs.
public struct HeuristicDesignParser: DesignMarkdownParsing, Sendable {
    public init() {}

    public func parse(_ markdown: String, seed: ThemeConfig) -> DesignParseResult {
        // 1) Structured block short-circuit — the authoritative path.
        if let structured = parseStructured(markdown, seed: seed) {
            return structured
        }

        var config = seed
        var extracted: [DesignParseResult.Field: String] = [:]
        var warnings: [String] = []
        var hexHits = 0
        var keywordHits = 0

        let lower = markdown.lowercased()

        // 2) Label-aware hex colors.
        var sawDarkHint = false
        if let primary = labeledHex(in: markdown, labels: ["primary", "brand color", "main color", "tint color"]) {
            config.primaryHex = primary; extracted[.primary] = "#\(primary)"; hexHits += 1
        }
        if let base = labeledHex(in: markdown, labels: ["base", "background", "surface", "paper", "canvas", "page"]) {
            config.baseHex = base; extracted[.base] = "#\(base)"; hexHits += 1
            sawDarkHint = luminance(ofHex: base) < 0.4
        }
        if let secondary = labeledHex(in: markdown, labels: ["secondary"]) {
            config.secondaryHex = secondary; extracted[.secondary] = "#\(secondary)"; hexHits += 1
        }
        if let accent = labeledHex(in: markdown, labels: ["accent", "highlight"]) {
            config.accentHex = accent; extracted[.accent] = "#\(accent)"; hexHits += 1
        }
        // Fallback: first unlabeled hex becomes primary when nothing labeled it.
        if extracted[.primary] == nil, let first = firstHex(in: markdown) {
            config.primaryHex = first; extracted[.primary] = "#\(first)"; hexHits += 1
            warnings.append("No labeled primary color found — used the first hex in the document.")
        }

        // 3) Light/dark.
        if containsAny(lower, ["dark mode", "dark theme", "midnight", "night theme", "on dark", "dark ui"]) {
            config.dark = true; extracted[.dark] = "true"; keywordHits += 1
        } else if containsAny(lower, ["light mode", "light theme", "bright", "on light", "light ui"]) {
            config.dark = false; extracted[.dark] = "false"; keywordHits += 1
        } else if sawDarkHint {
            config.dark = true; extracted[.dark] = "true (inferred from a dark base color)"
            warnings.append("Dark mode inferred from the base color's luminance.")
        }

        // 4) Roundedness → radiusScale.
        if let r = scaleFromKeywords(lower, mapping: [
            (["sharp", "square corners", "no radius", "no rounding", "hard edges", "brutalist"], 0.3),
            (["slightly rounded", "subtle radius", "small corners"], 0.7),
            (["rounded", "soft corners", "friendly", "pill", "very rounded", "fully rounded"], 1.4),
        ]) {
            config.radiusScale = r; extracted[.radiusScale] = fmt(r); keywordHits += 1
        }

        // 4) Spacing density → spacingScale.
        if let s = scaleFromKeywords(lower, mapping: [
            (["compact", "dense", "tight", "condensed"], 0.82),
            (["airy", "spacious", "generous spacing", "roomy", "breathing room"], 1.3),
        ]) {
            config.spacingScale = s; extracted[.spacingScale] = fmt(s); keywordHits += 1
        }

        // 4) Shadow / elevation → shadowScale.
        if let sh = scaleFromKeywords(lower, mapping: [
            (["flat", "no shadow", "no shadows", "shadowless", "no elevation"], 0),
            (["subtle shadow", "soft shadow"], 0.7),
            (["elevated", "floating", "deep shadow", "strong shadow", "heavy shadow"], 1.5),
        ]) {
            config.shadowScale = sh; extracted[.shadowScale] = fmt(sh); keywordHits += 1
        }

        // 4) Tint strength.
        if let t = scaleFromKeywords(lower, mapping: [
            (["monochrome", "grayscale", "greyscale", "neutral palette", "no tint"], 0),
            (["vibrant", "saturated", "colorful", "bold colors"], 0.12),
        ]) {
            config.tint = t; extracted[.tint] = fmt(t); keywordHits += 1
        }

        // 4) Font family cues (only families the engine renders, see `Theme.makeFont`).
        if let font = fontFromKeywords(lower) {
            config.font = font; extracted[.font] = font; keywordHits += 1
        }

        let confidence: DesignParseResult.Confidence
        if hexHits >= 1 && keywordHits >= 1 {
            confidence = .medium
        } else if hexHits >= 1 || keywordHits >= 1 {
            confidence = .low
        } else {
            confidence = .low
            warnings.append("Nothing recognizable found — fell back to the seed theme. Add colors or descriptive words.")
        }

        return DesignParseResult(config: config, confidence: confidence, method: .heuristic,
                                 extracted: extracted, warnings: warnings)
    }

    // MARK: - Structured block

    /// Looks for an authoritative `key: value` block: a fenced ` ```themekit ` or
    /// ` ```json ` block, or YAML-style `---` front-matter. Returns `nil` when none
    /// carries recognizable keys, so the prose heuristics run instead.
    private func parseStructured(_ markdown: String, seed: ThemeConfig) -> DesignParseResult? {
        // A) ```json block → decode straight into ThemeConfig.
        if let json = fencedBlock(in: markdown, languages: ["json"]),
           let data = json.data(using: .utf8),
           let cfg = try? ThemeConfig(jsonData: data) {
            return DesignParseResult(config: cfg, confidence: .high, method: .heuristic,
                                     extracted: extracted(from: cfg),
                                     warnings: [])
        }

        // B) ```themekit block or front-matter → key: value lines.
        let block = fencedBlock(in: markdown, languages: ["themekit", "theme", "tokens"])
            ?? frontMatter(in: markdown)
        guard let block, let result = applyKeyValues(block, to: seed) else { return nil }
        return result
    }

    /// Parses `key: value` lines into a config. Returns `nil` if no key was recognized.
    private func applyKeyValues(_ block: String, to seed: ThemeConfig) -> DesignParseResult? {
        var config = seed
        var extracted: [DesignParseResult.Field: String] = [:]
        var recognized = false

        for rawLine in block.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            var value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !value.isEmpty else { continue }

            switch key {
            case "primary", "primaryhex", "brand":
                if let h = normalizeHex(value) { config.primaryHex = h; extracted[.primary] = "#\(h)"; recognized = true }
            case "base", "basehex", "background", "surface":
                if let h = normalizeHex(value) { config.baseHex = h; extracted[.base] = "#\(h)"; recognized = true }
            case "secondary", "secondaryhex":
                if let h = normalizeHex(value) { config.secondaryHex = h; extracted[.secondary] = "#\(h)"; recognized = true }
            case "accent", "accenthex":
                if let h = normalizeHex(value) { config.accentHex = h; extracted[.accent] = "#\(h)"; recognized = true }
            case "tint":
                if let d = Double(value) { config.tint = clamp(d, 0, 0.25); extracted[.tint] = fmt(config.tint); recognized = true }
            case "dark", "darkmode":
                let b = boolValue(value); config.dark = b; extracted[.dark] = "\(b)"; recognized = true
            case "font", "fontfamily":
                if let f = fontFamily(value) { config.font = f; extracted[.font] = f; recognized = true }
            case "fontscale":
                if let d = Double(value) { config.fontScale = d; extracted[.fontScale] = fmt(d); recognized = true }
            case "radiusscale", "radius":
                if let d = Double(value) { config.radiusScale = d; extracted[.radiusScale] = fmt(d); recognized = true }
            case "spacingscale", "spacing":
                if let d = Double(value) { config.spacingScale = d; extracted[.spacingScale] = fmt(d); recognized = true }
            case "shadowscale", "shadow":
                if let d = Double(value) { config.shadowScale = d; extracted[.shadowScale] = fmt(d); recognized = true }
            default:
                continue
            }
        }
        guard recognized else { return nil }
        return DesignParseResult(config: config, confidence: .high, method: .heuristic,
                                 extracted: extracted, warnings: [])
    }

    // MARK: - Extraction helpers

    /// All recognizable values of a fully-known config (used after a ```json decode).
    private func extracted(from cfg: ThemeConfig) -> [DesignParseResult.Field: String] {
        var e: [DesignParseResult.Field: String] = [
            .primary: "#\(cfg.primaryHex)",
            .tint: fmt(cfg.tint),
            .dark: "\(cfg.dark)",
            .font: cfg.font,
            .fontScale: fmt(cfg.fontScale),
            .radiusScale: fmt(cfg.radiusScale),
            .spacingScale: fmt(cfg.spacingScale),
            .shadowScale: fmt(cfg.shadowScale),
        ]
        if let b = cfg.baseHex { e[.base] = "#\(b)" }
        if let s = cfg.secondaryHex { e[.secondary] = "#\(s)" }
        if let a = cfg.accentHex { e[.accent] = "#\(a)" }
        return e
    }

    /// First hex AT OR AFTER the earliest matched label on a line, so a line like
    /// "secondary #A and accent #B" associates each hex with its own label
    /// (falls back to any hex on the line if none follows the label).
    private func labeledHex(in text: String, labels: [String]) -> String? {
        for rawLine in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine).lowercased()
            guard let labelStart = labels.compactMap({ line.range(of: $0)?.lowerBound }).min() else { continue }
            if let hex = firstHex(in: String(line[labelStart...])) { return hex }
            if let hex = firstHex(in: line) { return hex }
        }
        return nil
    }

    /// First hex colour anywhere in `text`, normalized to 6-digit lowercase.
    private func firstHex(in text: String) -> String? {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        // 6-digit first, then 3-digit. `#` optional; require a word boundary so we
        // don't grab the leading 6 chars of an 8-digit RRGGBBAA value mid-token.
        for pattern in ["#([0-9a-fA-F]{6})\\b", "#([0-9a-fA-F]{3})\\b"] {
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            if let m = re.firstMatch(in: text, range: range), m.numberOfRanges > 1 {
                let hex = ns.substring(with: m.range(at: 1))
                return expandHex(hex)
            }
        }
        return nil
    }

    private func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }

    private func scaleFromKeywords(_ text: String, mapping: [([String], Double)]) -> Double? {
        for (keywords, value) in mapping where containsAny(text, keywords) { return value }
        return nil
    }

    private func fontFromKeywords(_ text: String) -> String? {
        if containsAny(text, ["serif"]) && !text.contains("sans-serif") && !text.contains("sans serif") { return "SystemSerif" }
        if containsAny(text, ["monospace", "monospaced", "mono font", "code font", "terminal"]) { return "SystemMono" }
        if containsAny(text, ["rounded font", "rounded type", "sf rounded"]) { return "SystemRounded" }
        if containsAny(text, ["system font", "native font", "san francisco", "sf pro"]) { return "System" }
        if containsAny(text, ["montserrat"]) { return "Montserrat" }
        return nil
    }

    /// Map a free `font:` value onto a renderable family (else nil).
    private func fontFamily(_ value: String) -> String? {
        let v = value.lowercased()
        switch v {
        case "system": return "System"
        case "systemrounded", "rounded": return "SystemRounded"
        case "systemserif", "serif": return "SystemSerif"
        case "systemmono", "mono", "monospace", "monospaced": return "SystemMono"
        case "montserrat": return "Montserrat"
        default:
            // Unknown branded sans → Montserrat (the bundled custom family).
            return "Montserrat"
        }
    }

    // MARK: - Markdown block helpers

    /// Returns the body of the first fenced code block whose language tag is in
    /// `languages` (case-insensitive).
    private func fencedBlock(in markdown: String, languages: [String]) -> String? {
        let langs = languages.map { $0.lowercased() }
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces).lowercased()
                var body: [String] = []
                var j = i + 1
                while j < lines.count, !lines[j].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[j]); j += 1
                }
                if langs.contains(lang) { return body.joined(separator: "\n") }
                i = j + 1
                continue
            }
            i += 1
        }
        return nil
    }

    /// Returns YAML-style front-matter (between leading `---` fences), if present.
    private func frontMatter(in markdown: String) -> String? {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first?.trimmingCharacters(in: .whitespaces), first == "---" else { return nil }
        var body: [String] = []
        var j = 1
        while j < lines.count, lines[j].trimmingCharacters(in: .whitespaces) != "---" {
            body.append(lines[j]); j += 1
        }
        return j < lines.count ? body.joined(separator: "\n") : nil
    }

    // MARK: - Value helpers

    private func normalizeHex(_ raw: String) -> String? {
        let s = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        let hex = s.trimmingCharacters(in: .whitespaces)
        if hex.count == 6, hex.allSatisfy(\.isHexDigit) { return hex.lowercased() }
        if hex.count == 3, hex.allSatisfy(\.isHexDigit) { return expandHex(hex) }
        return nil
    }

    /// Expand a 3-digit hex (`abc`) to 6 (`aabbcc`); pass 6-digit through, lowercased.
    private func expandHex(_ hex: String) -> String {
        if hex.count == 3 {
            return hex.lowercased().map { "\($0)\($0)" }.joined()
        }
        return hex.lowercased()
    }

    private func boolValue(_ raw: String) -> Bool {
        ["true", "yes", "on", "1", "dark", "enabled"].contains(raw.lowercased())
    }

    /// Relative luminance (0…1) of a 6-digit hex, for dark inference.
    private func luminance(ofHex hex: String) -> Double {
        let h = expandHex(hex)
        guard h.count == 6, let v = Int(h, radix: 16) else { return 1 }
        let r = Double((v >> 16) & 0xff) / 255
        let g = Double((v >> 8) & 0xff) / 255
        let b = Double(v & 0xff) / 255
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }
    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
}
