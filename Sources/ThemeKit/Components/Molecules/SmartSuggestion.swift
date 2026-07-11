//
//  SmartSuggestion.swift
//  ThemeKit
//
//  Molecule. An inline "smart / AI suggestion" banner — a sparkle icon, an accent
//  label prefix ("Smart tip:") and a message, on a soft tinted surface. Optionally
//  tappable. Token-bound.
//
//  ```swift
//  SmartSuggestion("The Berlin outbound is 12% cheaper on Sat 13 Sep.")
//      .label("Smart tip").accent(.success).onTap { applySuggestion() }
//  ```
//

import SwiftUI

public struct SmartSuggestion: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let message: String
    // Appearance/behaviour — mutated only through the modifiers below (R2).
    private var label: String?
    private var systemImage = "sparkles"
    private var tint: SemanticColor = .success
    private var onTap: (() -> Void)?
    private var actionTitle: String?
    private var onAction: (() -> Void)?
    private var bordered = true

    public init(_ message: String) { self.message = message }   // R1

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous) }

    public var body: some View {
        content
            .padding(density.scale(Theme.SpacingKey.md.value))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.bg, in: shape)
            .overlay { if bordered { shape.stroke(tint.base.opacity(0.35), lineWidth: 1) } }
            .contentShape(shape)
            .onTapGesture { onTap?() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel([label, message].compactMap { $0 }.joined(separator: ", "))
    }

    private var content: some View {
        HStack(alignment: .top, spacing: density.scale(Theme.SpacingKey.sm.value)) {
            Image(systemName: systemImage).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint.base)
            (labelText + messageText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let actionTitle, let onAction {
                Button { onAction() } label: {
                    Text(actionTitle).textStyle(.labelSm700).foregroundStyle(tint.strong).fixedSize()
                }.buttonStyle(.plain)
            } else if onTap != nil {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(tint.base).mirrorsInRTL()
            }
        }
    }

    private var labelText: Text {
        guard let label else { return Text("") }
        return Text(label + ": ").font(.system(size: 14, weight: .semibold)).foregroundColor(tint.strong)
    }
    private var messageText: Text {
        Text(message).font(.system(size: 14, weight: .semibold)).foregroundColor(theme.text(.textPrimary))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SmartSuggestion {
    /// An accent label prefix (e.g. "Smart tip").
    func label(_ text: String?) -> Self { copy { $0.label = text } }
    /// The leading icon (default a sparkle).
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    /// Token-fed accent for the surface / label / icon (default success green);
    /// `nil` restores the default. Standard accent vocabulary (flexibility audit §6).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.tint = color ?? .success } }
    /// Token-fed tint for the surface / accent (default success green).
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func tint(_ color: SemanticColor) -> Self { accent(color) }
    /// Makes the whole banner tappable (adds a trailing chevron).
    func onTap(_ action: @escaping () -> Void) -> Self { copy { $0.onTap = action } }
    /// A trailing text action (e.g. "Apply").
    func action(_ title: String, perform: @escaping () -> Void) -> Self { copy { $0.actionTitle = title; $0.onAction = perform } }
    /// Draw the soft border (default on).
    func bordered(_ on: Bool) -> Self { copy { $0.bordered = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("SmartSuggestion") {
        PreviewCase("Tappable tip") { SmartSuggestion("The Berlin outbound is 12% cheaper on Sat 13 Sep.").label("Smart tip").onTap { } }
        PreviewCase("Warning + action") { SmartSuggestion("Add a checked bag now and save ₺150.").label("Deal").accent(.warning).action("Add") { } }
        PreviewCase("Borderless") { SmartSuggestion("Prices for these dates are trending up.").bordered(false) }
    }
}
