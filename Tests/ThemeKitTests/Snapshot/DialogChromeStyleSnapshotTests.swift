//
//  DialogChromeStyleSnapshotTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 22.09.2026.
//
//  Visual-regression coverage for the `DialogStyle` path: a host-shaped dialog
//  card that looks nothing like the stock one — leading-aligned, a flat bordered
//  surface on the tighter `field` corner, the kind glyph inline before the
//  title, the close button in the title row, compact buttons in a trailing row,
//  no shadow and its own `xl` screen margin — presented through the real
//  `.dialog(isPresented:title:…)`, so ThemeKit's scrim and placement sit around
//  it. The style is fed from theme tokens, so the dark case re-skins.
//  iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

// MARK: - Host-shaped style

/// A leading-aligned dialog card: kind glyph + title + close in one row, the
/// message under it, a trailing row of small buttons, a flat bordered surface
/// and an `xl` margin of its own instead of the stock `lg`.
private struct LeadingCardDialogStyle: DialogStyle {
    func makeBody(configuration: DialogStyleConfiguration) -> some View {
        LeadingCardDialogBody(configuration: configuration)
    }
}

private struct LeadingCardDialogBody: View {
    let configuration: DialogStyleConfiguration
    @Environment(\.theme) private var theme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
                if let kind = configuration.kind {
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.resolve(kind.semanticColor).base)
                }
                Text(configuration.title)
                    .textStyle(.labelLg700)
                    .foregroundStyle(theme.text(.textPrimary))
                Spacer(minLength: Theme.SpacingKey.sm.value)
                if let onClose = configuration.onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
            if let message = configuration.message {
                Text(message)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Spacer(minLength: 0)
                if let secondary = configuration.secondaryAction {
                    ThemeButton(secondary.title, action: secondary.perform)
                        .variant(.ghost).color(.neutral).size(.small)
                        .disabled(secondary.isDisabled)
                }
                ThemeButton(configuration.primaryAction.title, action: configuration.primaryAction.perform)
                    .color(configuration.primaryAction.color ?? .primary).size(.small)
                    .loading(configuration.primaryAction.isLoading)
            }
            .padding(.top, Theme.SpacingKey.xs.value)
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: configuration.maxWidth, alignment: .leading)
        .background(theme.background(.bgWhite), in: shape)
        .overlay(shape.strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
        .padding(Theme.SpacingKey.xl.value)
    }
}

// MARK: - Suite

@available(iOS 16.0, *)
@MainActor
final class DialogChromeStyleSnapshotTests: SnapshotTestCase {

    /// A two-action dialog and a single-action one.
    func testCustomDialog_withAndWithoutSecondary() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                stage(height: 260)
                    .dialog(isPresented: .constant(true), title: "Delete trip?",
                            message: "This action cannot be undone.",
                            primaryTitle: "Delete", secondaryTitle: "Cancel", onSecondary: {})
                stage(height: 220)
                    .dialog(isPresented: .constant(true), title: "Booking saved",
                            message: "We sent the details to your email.",
                            primaryTitle: "Done")
            }
            .dialogStyle(LeadingCardDialogStyle())
        )
    }

    /// The kind glyph and the close button, which the style places itself.
    func testCustomDialog_kindAndClosable() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                stage(height: 260)
                    .dialog(isPresented: .constant(true), title: "Payment failed",
                            message: "Your card was declined. Try another method.",
                            primaryTitle: "Retry", secondaryTitle: "Cancel", onSecondary: {},
                            kind: .error, closable: true)
                stage(height: 220)
                    .dialog(isPresented: .constant(true), title: "Seat upgraded",
                            message: "Enjoy the extra legroom.",
                            primaryTitle: "Great", kind: .success, closable: true)
            }
            .dialogStyle(LeadingCardDialogStyle())
        )
    }

    /// The stock card drawn through `makeBody` — the same pixels the built-in
    /// card draws — above the custom one.
    func testCustomDialog_besideTheDefaultStyle() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                stage(height: 440)
                    .dialog(isPresented: .constant(true), title: "Payment failed",
                            message: "Your card was declined. Try another method.",
                            primaryTitle: "Retry", secondaryTitle: "Cancel", onSecondary: {},
                            kind: .error, closable: true)
                    .dialogStyle(.default)
                stage(height: 260)
                    .dialog(isPresented: .constant(true), title: "Payment failed",
                            message: "Your card was declined. Try another method.",
                            primaryTitle: "Retry", secondaryTitle: "Cancel", onSecondary: {},
                            kind: .error, closable: true)
                    .dialogStyle(LeadingCardDialogStyle())
            }
        )
    }

    /// RTL: the glyph, title and close button swap sides, and the button row
    /// hugs the leading edge.
    func testCustomDialog_rtl() {
        assertComponentSnapshot(
            stage(height: 260)
                .dialog(isPresented: .constant(true), title: "Payment failed",
                        message: "Your card was declined. Try another method.",
                        primaryTitle: "Retry", secondaryTitle: "Cancel", onSecondary: {},
                        kind: .error, closable: true)
                .dialogStyle(LeadingCardDialogStyle()),
            layoutDirection: .rightToLeft
        )
    }

    func testCustomDialog_darkScheme() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                stage(height: 260)
                    .dialog(isPresented: .constant(true), title: "Delete trip?",
                            message: "This action cannot be undone.",
                            primaryTitle: "Delete", secondaryTitle: "Cancel", onSecondary: {},
                            kind: .warning, closable: true)
                stage(height: 220)
                    .dialog(isPresented: .constant(true), title: "Booking saved",
                            message: "We sent the details to your email.",
                            primaryTitle: "Done")
            }
            .dialogStyle(LeadingCardDialogStyle()),
            colorScheme: .dark
        )
    }

    // MARK: Fixtures

    /// A tinted page for the dialog to present over, at a fixed height so the
    /// scrim has an area to cover.
    private func stage(height: CGFloat) -> some View {
        DialogStage().frame(height: height)
    }
}

/// The page behind the dialog — a token surface, so the scrim and the card read
/// against something in both schemes.
private struct DialogStage: View {
    @Environment(\.theme) private var theme

    var body: some View {
        theme.background(.bgSecondaryLight)
    }
}
#endif
