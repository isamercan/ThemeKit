//
//  DesignSpecCatalog.swift
//  ThemeKit
//  Created by İsa Mercan on 30.06.2026.
//
//  Loads `design.md` specs from three sources: the bundled catalog (shipped with
//  the package), a local file (the file picker's URL), and a remote https URL.
//  Networking is Foundation-only (`URLSession`) — no third-party dependency — and
//  is hardened: https-only, a byte cap, and a text content-type check. The fetched
//  body is treated as untrusted text (the parser never executes it).
//

import Foundation

public enum DesignSpecError: Error, LocalizedError, Equatable {
    case notFound
    case unreadable
    case insecureURL
    case tooLarge(Int)
    case badResponse(Int)
    case notText

    public var errorDescription: String? {
        switch self {
        case .notFound: return "The design file could not be found."
        case .unreadable: return "The design file could not be read as text."
        case .insecureURL: return "Only https URLs are allowed."
        case .tooLarge(let max): return "The file is larger than the \(max / 1024) KB limit."
        case .badResponse(let code): return "The server responded with status \(code)."
        case .notText: return "The URL did not return a text/markdown document."
        }
    }
}

public enum DesignSpecCatalog {

    /// Subdirectory under the package's resource bundle where `*.design.md` live.
    static let bundledSubdirectory = "DesignSpecs"
    /// Default cap for remote fetches (256 KB) — design docs are small.
    public static let defaultMaxBytes = 256 * 1024

    // MARK: - Bundled

    /// Every bundled design spec, sorted by title. Empty if none ship (or aren't
    /// discoverable — the catalog test guards against that).
    ///
    /// `.process("Resources")` flattens subdirectories (the bundled fonts and theme
    /// JSON are found at the bundle root too), so we scan the root for `*.design.md`
    /// and fall back to the `DesignSpecs/` subdirectory in case a future toolchain
    /// preserves the hierarchy.
    public static func bundled() -> [DesignSpec] {
        var urls = (Bundle.module.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasSuffix(".design.md") }
        if urls.isEmpty {
            urls = Bundle.module.urls(forResourcesWithExtension: "md", subdirectory: bundledSubdirectory) ?? []
        }
        return urls
            .compactMap { try? spec(fromFileURL: $0, source: .bundled(resource: idForBundled($0))) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// A single bundled spec by id (its filename slug, e.g. `"linear-dark"`).
    public static func bundled(id: String) -> DesignSpec? {
        bundled().first { $0.id == id }
    }

    // MARK: - File

    /// Loads a spec from a local file URL (e.g. the document picker's result).
    /// The caller owns security-scoped access around this call.
    public static func load(fileURL: URL) throws -> DesignSpec {
        try spec(fromFileURL: fileURL, source: .file(fileURL))
    }

    // MARK: - Remote

    /// Fetches a remote markdown document and parses its metadata. Hardened:
    /// https-only, `maxBytes` cap, and a text content-type check.
    public static func load(
        remoteURL: URL,
        session: URLSession = .shared,
        maxBytes: Int = defaultMaxBytes
    ) async throws -> DesignSpec {
        guard remoteURL.scheme?.lowercased() == "https" else { throw DesignSpecError.insecureURL }

        var request = URLRequest(url: remoteURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("text/markdown, text/plain;q=0.9, */*;q=0.1", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            guard (200..<300).contains(http.statusCode) else { throw DesignSpecError.badResponse(http.statusCode) }
            if let type = http.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
               !type.isEmpty,
               !(type.contains("text/") || type.contains("markdown") || type.contains("octet-stream")) {
                throw DesignSpecError.notText
            }
        }
        guard data.count <= maxBytes else { throw DesignSpecError.tooLarge(maxBytes) }
        guard let markdown = String(data: data, encoding: .utf8) else { throw DesignSpecError.unreadable }

        return makeSpec(
            id: slug(remoteURL.deletingPathExtension().lastPathComponent),
            markdown: markdown,
            source: .remote(remoteURL)
        )
    }

    // MARK: - Pasted

    /// Wraps raw pasted markdown as a spec.
    public static func pasted(_ markdown: String, id: String = "pasted") -> DesignSpec {
        makeSpec(id: id, markdown: markdown, source: .pasted)
    }

    // MARK: - Construction

    private static func spec(fromFileURL url: URL, source: DesignSpec.Source) throws -> DesignSpec {
        guard let data = try? Data(contentsOf: url) else { throw DesignSpecError.notFound }
        guard let markdown = String(data: data, encoding: .utf8) else { throw DesignSpecError.unreadable }
        let id: String
        if case .bundled(let resource) = source { id = resource } else { id = idForBundled(url) }
        return makeSpec(id: id, markdown: markdown, source: source)
    }

    /// Builds a `DesignSpec`, deriving title/summary from the markdown.
    private static func makeSpec(id: String, markdown: String, source: DesignSpec.Source) -> DesignSpec {
        let meta = metadata(from: markdown)
        let title = meta.title ?? prettify(id)
        return DesignSpec(id: id, title: title, summary: meta.summary, source: source, rawMarkdown: markdown)
    }

    /// `linear-dark.design.md` → `linear-dark`.
    private static func idForBundled(_ url: URL) -> String {
        var name = url.deletingPathExtension().lastPathComponent   // drops ".md"
        if name.hasSuffix(".design") { name = String(name.dropLast(".design".count)) }
        return slug(name)
    }

    // MARK: - Metadata

    /// Title (front-matter `title:` or first `#` heading) and summary (front-matter
    /// `summary:` or the first prose paragraph).
    private static func metadata(from markdown: String) -> (title: String?, summary: String?) {
        var title: String?
        var summary: String?
        var inFrontMatter = false
        var inCodeFence = false

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for (index, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if index == 0, line == "---" { inFrontMatter = true; continue }
            if inFrontMatter {
                if line == "---" { inFrontMatter = false; continue }
                if let v = frontMatterValue(line, key: "title") { title = title ?? v }
                if let v = frontMatterValue(line, key: "summary") { summary = summary ?? v }
                continue
            }

            if line.hasPrefix("```") { inCodeFence.toggle(); continue }
            if inCodeFence { continue }

            if title == nil, line.hasPrefix("# ") {
                title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if summary == nil, !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("---"),
               !line.hasPrefix(">"), !line.hasPrefix("```") {
                summary = line
            }
            if title != nil, summary != nil { break }
        }
        return (title, summary)
    }

    private static func frontMatterValue(_ line: String, key: String) -> String? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        guard line[..<colon].trimmingCharacters(in: .whitespaces).lowercased() == key else { return nil }
        let value = line[line.index(after: colon)...]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return value.isEmpty ? nil : value
    }

    // MARK: - String helpers

    private static func slug(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let mapped = lowered.map { ch -> Character in
            (ch.isLetter || ch.isNumber) ? ch : "-"
        }
        let collapsed = String(mapped).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
        return collapsed.isEmpty ? "design" : collapsed
    }

    private static func prettify(_ id: String) -> String {
        id.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
