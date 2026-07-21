//
//  ShareButton.swift
//  ThemeKit
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Atom. A share action wrapping SwiftUI `ShareLink` with kit chrome — opens the
/// system share sheet for a URL or string. (An iOS-native kit staple.)
public struct ShareButton: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let item: String

    // Appearance — mutated only through the modifiers below (R2).
    private var systemImage = "square.and.arrow.up"
    private var size: ButtonSize?   // nil → the stock 44 pt chrome
    private var accent: SemanticColor?

    public init(_ title: String = String(themeKit: "Share"), item: String) {
        self.title = title
        self.item = item
    }

    public var body: some View {
        // `ShareLink` is iOS 16-only. macOS 14 ≥ its macOS 13 floor, so only
        // iOS branches; below 16 the named ``LegacyActivityShareButton`` unit
        // presents `UIActivityViewController` instead (ADR-0007 §D2 rule 2/3).
        #if os(iOS)
        if #available(iOS 16.0, *) {
            ShareLink(item: item) { chrome }
        } else {
            LegacyActivityShareButton(item: item) { chrome }
        }
        #else
        ShareLink(item: item) { chrome }
        #endif
    }

    /// The kit chrome shared by the native `ShareLink` and the legacy unit.
    private var chrome: some View {
        Label(title, systemImage: systemImage)
            .textStyle(size?.textStyle ?? .labelBase600)
            .padding(.horizontal, size?.horizontalPadding ?? Theme.SpacingKey.md.value)
            .frame(height: size?.height ?? 44)
            .foregroundStyle(accent.map { theme.resolve($0).onSolid } ?? theme.foreground(.fgSecondary))
            .background(accent.map { theme.resolve($0).solid } ?? theme.foreground(.fgHero),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
    }
}

#if os(iOS)
/// Named legacy unit (ADR-0007 §D2 rule 3): below iOS 16 there is no
/// `ShareLink`, so the share action is a plain button presenting the UIKit
/// share sheet (`UIActivityViewController`) in a sheet — same capability,
/// system chrome instead of the SwiftUI-managed presentation.
struct LegacyActivityShareButton<LabelContent: View>: View {
    let item: String
    @ViewBuilder let label: () -> LabelContent

    @State private var isPresenting = false

    var body: some View {
        Button { isPresenting = true } label: { label() }
            .buttonStyle(.plain)
            .sheet(isPresented: $isPresenting) {
                LegacyActivityShareSheet(item: item)
                    .ignoresSafeArea()
            }
    }
}

/// The `UIActivityViewController` bridge behind ``LegacyActivityShareButton``.
private struct LegacyActivityShareSheet: UIViewControllerRepresentable {
    let item: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [item], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ShareButton {
    /// SF Symbol on the label (default `square.and.arrow.up`).
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    /// Kit button size ramp (height / padding / type); unset keeps the stock 44 pt chrome.
    func size(_ s: ButtonSize) -> Self { copy { $0.size = s } }
    /// Token-fed fill (label auto-contrasts); `nil` keeps the hero fill.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("ShareButton") {
        PreviewCase("Default") { ShareButton(item: "https://github.com/isamercan/ThemeKit") }
        PreviewCase("Custom · small") {
            ShareButton("Send", item: "https://github.com/isamercan/ThemeKit")
                .icon("paperplane.fill")
                .accent(.success)
                .size(.small)
        }
    }
}
