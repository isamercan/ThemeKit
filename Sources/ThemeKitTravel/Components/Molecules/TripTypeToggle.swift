//
//  TripTypeToggle.swift
//  ThemeKit
//
//  Molecule. A compact pill-segmented control — the selected option is an
//  accent-filled pill inside a soft container. Generic (one-way / round-trip /
//  multi-city, or any options), with optional per-option icons. Token-bound.
//
//  ```swift
//  TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $trip)
//      .icons(["arrow.right", "arrow.left.arrow.right", "point.3.connected.trianglepath.dotted"])
//  ```
//

import SwiftUI
import ThemeKit

public struct TripTypeToggle: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let options: [String]
    @Binding private var selection: Int
    // Appearance — mutated only through the modifiers below (R2).
    private var icons: [String] = []
    private var accent: SemanticColor?
    private var fullWidth = true

    public init(_ options: [String], selection: Binding<Int>) {   // R1
        self.options = options
        self._selection = selection
    }

    private var accentSemantic: SemanticColor { accent ?? .primary }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, option in pill(i, option) }
        }
        .padding(4)
        .background(theme.background(.bgSecondary), in: Capsule())
        .frame(maxWidth: fullWidth ? .infinity : nil)
    }

    private func pill(_ i: Int, _ option: String) -> some View {
        let isOn = i == selection
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { selection = i }
        } label: {
            HStack(spacing: 5) {
                if i < icons.count { Image(systemName: icons[i]).font(.system(size: 12, weight: .semibold)) }
                Text(option).textStyle(.labelSm700).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(isOn ? accentSemantic.onSolid : theme.text(.textSecondary))
            .padding(.horizontal, density.scale(Theme.SpacingKey.sm.value))
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: 36)
            .background(isOn ? accentSemantic.solid : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TripTypeToggle {
    /// Per-option leading SF Symbols (aligned to `options` by index).
    func icons(_ symbols: [String]) -> Self { copy { $0.icons = symbols } }
    /// Token-fed accent for the selected pill (default primary).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Stretch pills to fill the width (default on); off = intrinsic width.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.fullWidth = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var sel = 1
    PreviewMatrix("TripTypeToggle") {
        PreviewCase("Icons") {
            TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $sel)
                .icons(["arrow.right", "arrow.left.arrow.right", "point.3.connected.trianglepath.dotted"])
        }
        PreviewCase("Accent") {
            TripTypeToggle(["One way", "Round trip", "Multi-city"], selection: $sel)
                .accent(.success)
        }
        PreviewCase("Intrinsic width") {
            TripTypeToggle(["One way", "Round trip"], selection: .constant(0))
                .fullWidth(false)
        }
    }
}
