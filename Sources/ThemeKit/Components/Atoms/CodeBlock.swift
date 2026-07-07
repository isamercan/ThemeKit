//
//  CodeBlock.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  Atom. A terminal-style code mockup — monospaced lines with optional prefixes
//  ("$", line numbers…), per-line semantic highlights, horizontal scrolling for
//  long lines and an optional copy-to-clipboard button. Token-bound (dark
//  surface from the neutral ladder, highlights from ``SemanticColor``).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// One line of a ``CodeBlock``.
public struct CodeLine: Equatable {
    public let text: String
    /// Leading gutter text — a shell prompt ("$", ">") or a line number.
    public let prefix: String?
    /// Highlights the whole line with the color's solid fill.
    public let highlight: SemanticColor?

    public init(_ text: String, prefix: String? = nil, highlight: SemanticColor? = nil) {
        self.text = text
        self.prefix = prefix
        self.highlight = highlight
    }
}

/// Atom. A dark terminal-style code block. (daisyUI "Mockup Code".)
///
/// ```swift
/// CodeBlock([
///     CodeLine("npm i themekit", prefix: "$"),
///     CodeLine("installing...", prefix: ">", highlight: .warning),
///     CodeLine("Done!", prefix: ">", highlight: .success),
/// ])
/// .copyable()
/// ```
public struct CodeBlock: View {
    @Environment(\.theme) private var theme

    // Required content (R1).
    private let lines: [CodeLine]
    // Appearance/config — mutated only through the modifiers below (R2).
    private var showsCopyButton = false

    @State private var copied = false

    public init(_ lines: [CodeLine]) {   // R1
        self.lines = lines
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    row(line)
                }
            }
            .padding(.vertical, Theme.SpacingKey.md.value)
            .padding(.trailing, showsCopyButton ? 36 : 0)
        }
        .background(SemanticColor.neutral.shade(.s900))
        .clipShape(shape)
        .overlay(alignment: .topTrailing) {
            if showsCopyButton { copyButton }
        }
        .accessibilityElement(children: .contain)
    }

    private func row(_ line: CodeLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.sm.value) {
            Text(line.prefix ?? "")
                .frame(minWidth: 18, alignment: .trailing)
                .foregroundStyle(line.highlight.map { $0.onSolid.opacity(0.7) }
                                 ?? SemanticColor.neutral.shade(.s500))
            Text(line.text)
                .foregroundStyle(line.highlight.map { $0.onSolid }
                                 ?? SemanticColor.neutral.shade(.s100))
        }
        .font(.system(.footnote, design: .monospaced))
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, 3)
        .background(line.highlight.map { $0.solid } ?? .clear)
    }

    private var copyButton: some View {
        Button(action: copyAll) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(copied ? SemanticColor.success.base
                                        : SemanticColor.neutral.shade(.s400))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(6)
        .accessibilityLabel(copied ? String(themeKit: "Copied") : String(themeKit: "Copy code"))
    }

    private func copyAll() {
        let text = lines.map(\.text).joined(separator: "\n")
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { copied = false }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CodeBlock {
    /// Show a copy-to-clipboard button in the top-trailing corner.
    func copyable(_ on: Bool = true) -> Self { copy { $0.showsCopyButton = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    VStack(spacing: 16) {
        CodeBlock([
            CodeLine("npm i themekit", prefix: "$"),
            CodeLine("installing...", prefix: ">"),
            CodeLine("Error! Enable maintainer mode.", prefix: ">", highlight: .warning),
            CodeLine("Done!", prefix: ">", highlight: .success),
        ])
        .copyable()

        CodeBlock([
            CodeLine("import SwiftUI", prefix: "1"),
            CodeLine("struct App: View { var body: some View { CodeBlock([]) } } // a deliberately long line to demonstrate horizontal scrolling", prefix: "2"),
            CodeLine("#Preview { App() }", prefix: "3"),
        ])
    }
    .padding()
    .background(theme.background(.bgSecondaryLight))
}
