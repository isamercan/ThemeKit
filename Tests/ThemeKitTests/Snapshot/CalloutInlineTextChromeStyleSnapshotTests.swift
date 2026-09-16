//
//  CalloutInlineTextChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  Visual-regression coverage for the `CalloutChromeStyle` and
//  `InlineTextStyle` paths: custom styles (light, dark, RTL), the explicit
//  `.default` styles (which must match the stock look), the new callout
//  alignment / full-width axes, linked callout text in the tone colour, and
//  the InlineText slots.
//  iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class CalloutInlineTextChromeStyleSnapshotTests: SnapshotTestCase {

    // MARK: Callout

    func testCallout_customChrome() {
        assertComponentSnapshot(calloutMatrix.calloutChromeStyle(SnapshotCalloutChrome()))
    }
    func testCallout_customChrome_dark() {
        assertComponentSnapshot(calloutMatrix.calloutChromeStyle(SnapshotCalloutChrome()), colorScheme: .dark)
    }
    func testCallout_customChrome_rtl() {
        assertComponentSnapshot(calloutMatrix.calloutChromeStyle(SnapshotCalloutChrome()), layoutDirection: .rightToLeft)
    }
    func testCallout_defaultChromeExplicit() {
        assertComponentSnapshot(calloutMatrix.calloutChromeStyle(.default))
    }
    func testCallout_alignmentAndFullWidth() {
        assertComponentSnapshot(VStack(alignment: .leading, spacing: 12) {
            Callout("Seats are filling up.").variant(.warning).calloutStyle(.soft)
                .leading { Image(systemName: "flame").font(.system(size: 20)) }
                .alignment(.center)
            Callout("Seats are filling up.").variant(.warning).calloutStyle(.soft)
                .leading { Image(systemName: "flame").font(.system(size: 20)) }
                .alignment(.center)
                .fullWidth()
        })
    }
    func testCallout_linksKeepTheTone() {
        assertComponentSnapshot(VStack(alignment: .leading, spacing: 12) {
            Callout("Check the fare rules before booking.").variant(.error).links([("fare rules", {})])
            Callout("Check the fare rules before booking.").variant(.success).calloutStyle(.soft).links([("fare rules", {})])
        })
    }

    private var calloutMatrix: some View {
        VStack(alignment: .leading, spacing: 12) {
            Callout("Your changes were saved.").variant(.success)
            Callout("Prices may change until you book.").variant(.warning).calloutStyle(.soft)
                .action("Details") {}
                .fullWidth()
            Callout("Read the fare rules first.").variant(.info).links([("fare rules", {})]).onClose {}
            Callout("Checking availability…").variant(.accent).calloutStyle(.soft)
                .leading { Image(systemName: "hourglass") }
                .statusLabel("Loading")
        }
    }

    // MARK: InlineText

    func testInlineText_slots() {
        assertComponentSnapshot(VStack(alignment: .leading, spacing: 12) {
            InlineText("Free cancellation").accent(.success)
                .leading { Image(systemName: "checkmark.circle") }
            InlineText("Read the Guidelines before publishing.", links: [("Guidelines", {})])
                .inlineStyle(.bodyBase400)
                .trailing { Badge("New").badgeStyle(.info).size(.small) }
        })
    }
    func testInlineText_customStyle() {
        assertComponentSnapshot(inlineMatrix.inlineTextStyle(SnapshotInlineTextStyle()))
    }
    func testInlineText_customStyle_dark() {
        assertComponentSnapshot(inlineMatrix.inlineTextStyle(SnapshotInlineTextStyle()), colorScheme: .dark)
    }
    func testInlineText_customStyle_rtl() {
        assertComponentSnapshot(inlineMatrix.inlineTextStyle(SnapshotInlineTextStyle()), layoutDirection: .rightToLeft)
    }
    func testInlineText_defaultStyleExplicit() {
        assertComponentSnapshot(inlineMatrix.inlineTextStyle(.default))
    }

    private var inlineMatrix: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineText("A plain sentence with no anchors.")
            InlineText("By continuing you accept the Terms and the Privacy Policy.",
                       links: [("Terms", {}), ("Privacy Policy", {})])
            InlineText("Free cancellation").accent(.success)
                .leading { Image(systemName: "checkmark.circle") }
                .trailing { Image(systemName: "chevron.right") }
        }
    }
}

// MARK: - Fixture styles

/// A bordered callout: centred row, primary body text on the tone's light
/// surface, a 1pt tone stroke, and its own larger icon for the stock glyph.
private struct SnapshotCalloutChrome: CalloutChromeStyle {
    func makeBody(configuration: CalloutChromeStyleConfiguration) -> some View {
        SnapshotCalloutChromeBody(configuration: configuration)
    }
}

private struct SnapshotCalloutChromeBody: View {
    let configuration: CalloutChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
            if let symbol = configuration.leadingSystemImage {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .accessibilityLabel(configuration.statusLabel ?? configuration.text)
            } else {
                configuration.leading
            }
            configuration.content
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
                .frame(maxWidth: configuration.isFullWidth ? .infinity : nil, alignment: .leading)
            configuration.trailing
            configuration.actionButton
            configuration.closeButton
        }
        .foregroundStyle(configuration.tone.accent(theme))
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(configuration.tone.soft(theme),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(configuration.tone.accent(theme), lineWidth: 1)
        )
    }
}

/// A one-line inline text: primary medium body type, links recoloured to the
/// primary accent, slot glyphs in the tertiary text colour.
private struct SnapshotInlineTextStyle: InlineTextStyle {
    func makeBody(configuration: InlineTextStyleConfiguration) -> some View {
        SnapshotInlineTextBody(configuration: configuration)
    }
}

private struct SnapshotInlineTextBody: View {
    let configuration: InlineTextStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
            configuration.leading
            Text(relinked)
                .textStyle(.bodyBase500)
                .foregroundStyle(theme.text(.textPrimary))
                .lineLimit(1)
            configuration.trailing
        }
        .foregroundStyle(theme.text(.textTertiary))
    }

    /// The configuration's text with the link runs repainted; their `link`
    /// URLs stay, so taps still route.
    private var relinked: AttributedString {
        var text = configuration.attributedText
        for run in text.runs where run.link != nil {
            text[run.range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = theme.resolve(.primary).base
            text[run.range][AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = nil
        }
        return text
    }
}
#endif
