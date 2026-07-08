//
//  Mentions.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Mentions** — a multi-line input where typing a prefix
//  (default `@`) opens a filterable suggestion list; picking one inserts the
//  mention followed by a space. Detection tracks the trailing prefix token (the
//  one being typed), which is what SwiftUI's `TextField` reliably exposes.
//
//      Mentions(text: $note, options: teammates).placeholder("Write a note…")
//

import SwiftUI

/// One suggestion in a ``Mentions`` list.
public struct MentionOption: Identifiable, Sendable {
    public let value: String
    public let label: String
    public init(_ value: String, label: String? = nil) {
        self.value = value
        self.label = label ?? value
    }
    public var id: String { value }
}

public struct Mentions: View {
    @Environment(\.theme) private var theme

    @Binding private var text: String
    private let options: [MentionOption]
    // Appearance — mutated only through the modifiers below.
    private var prefix: Character = "@"
    private var placeholder: String = ""

    @State private var query: String?

    public init(text: Binding<String>, options: [MentionOption]) {   // R1
        self._text = text
        self.options = options
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .textStyle(.bodyBase400)
                .lineLimit(3...6)
                .padding(Theme.SpacingKey.md.value)
                .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
                .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value)
                    .strokeBorder(theme.border(query == nil ? .borderPrimary : .borderHero), lineWidth: query == nil ? 1 : 2))
                .onChange(of: text) { query = activeQuery() }

            if query != nil, !filtered.isEmpty {
                suggestions
            }
        }
    }

    private var suggestions: some View {
        VStack(spacing: 0) {
            ForEach(filtered) { opt in
                Button { insert(opt) } label: {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Text(String(prefix) + opt.value).textStyle(.labelSm600).foregroundStyle(theme.text(.textHero))
                        if opt.label != opt.value {
                            Text(opt.label).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value).strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
    }

    private var filtered: [MentionOption] {
        guard let q = query else { return [] }
        guard !q.isEmpty else { return options }
        return options.filter { $0.label.localizedCaseInsensitiveContains(q) || $0.value.localizedCaseInsensitiveContains(q) }
    }

    /// The query after the trailing prefix token, or `nil` if the caret isn't in one.
    private func activeQuery() -> String? {
        guard let idx = text.lastIndex(of: prefix) else { return nil }
        // The prefix must start a token (be at the start or follow whitespace).
        if idx > text.startIndex {
            let before = text[text.index(before: idx)]
            if !before.isWhitespace { return nil }
        }
        let after = text[text.index(after: idx)...]
        // A whitespace after the prefix closes the mention.
        if after.contains(where: { $0.isWhitespace }) { return nil }
        return String(after)
    }

    private func insert(_ option: MentionOption) {
        guard let idx = text.lastIndex(of: prefix) else { return }
        text = String(text[..<idx]) + String(prefix) + option.value + " "
        query = nil
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension Mentions {
    /// The trigger character (Ant `prefix`). Default `@`.
    func prefix(_ character: Character) -> Self { copy { $0.prefix = character } }
    /// Placeholder shown when empty.
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var text = "Great work "
        let people = [MentionOption("ada", label: "Ada Lovelace"), MentionOption("alan", label: "Alan Turing"),
                      MentionOption("grace", label: "Grace Hopper")]
        var body: some View { Mentions(text: $text, options: people).placeholder("Write a note…").padding() }
    }
    return Demo().environment(Theme.shared)
}
