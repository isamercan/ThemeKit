//
//  PhoneFrame.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  Organism. A phone-device mockup — a rounded bezel with a camera island /
//  notch and a home indicator wrapping arbitrary content at a phone aspect
//  ratio. Token-bound (bezel takes a semantic color).
//

import SwiftUI

/// The camera cutout style at the top of a ``PhoneFrame``.
public enum PhoneNotchStyle: String, CaseIterable {
    /// A floating pill (Dynamic-Island-like). Default.
    case island
    /// A notch attached to the top edge.
    case notch
    /// No cutout.
    case none
}

/// Organism. A phone bezel around arbitrary content. (daisyUI "Mockup Phone".)
///
/// ```swift
/// PhoneFrame {
///     Text("It's Glowtime.").padding()
/// }
/// .notch(.notch)
/// ```
public struct PhoneFrame<Content: View>: View {
    @Environment(\.theme) private var theme

    // Required content (R1).
    private let content: () -> Content
    // Appearance/config — mutated only through the modifiers below (R2).
    private var notchStyle: PhoneNotchStyle = .island
    private var bezel: SemanticColor = .neutral

    public init(@ViewBuilder content: @escaping () -> Content) {   // R1
        self.content = content
    }

    // Device geometry (physical mock, not themable surface).
    private let outerRadius: CGFloat = 44
    private let bezelWidth: CGFloat = 10
    private let aspectRatio: CGFloat = 9.0 / 19.5

    private var bezelColor: Color { bezel.shade(.s900) }

    private var screenShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: outerRadius - bezelWidth, style: .continuous)
    }

    public var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background(.bgElevatorPrimary))
            .clipShape(screenShape)
            .overlay(alignment: .top) { cutout }
            .overlay(alignment: .bottom) { homeIndicator }
            .padding(bezelWidth)
            .background(bezelColor, in: RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
            .aspectRatio(aspectRatio, contentMode: .fit)
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var cutout: some View {
        switch notchStyle {
        case .island:
            Capsule()
                .fill(bezelColor)
                .frame(width: 88, height: 22)
                .padding(.top, 8)
                .accessibilityHidden(true)
        case .notch:
            UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous)
                .fill(bezelColor)
                .frame(width: 140, height: 24)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }

    private var homeIndicator: some View {
        Capsule()
            .fill(bezel.shade(.s300))
            .frame(width: 96, height: 4)
            .padding(.bottom, 8)
            .accessibilityHidden(true)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PhoneFrame {
    /// Camera cutout style: island / notch / none (default island).
    func notch(_ style: PhoneNotchStyle) -> Self { copy { $0.notchStyle = style } }

    /// Bezel color family — the 900 ladder step frames the device (default neutral).
    func bezel(_ color: SemanticColor) -> Self { copy { $0.bezel = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    ScrollView {
        HStack(alignment: .top, spacing: 20) {
            PhoneFrame {
                VStack(spacing: 8) {
                    Spacer()
                    Text("Hello").textStyle(.headingSm)
                    Text("Dynamic island")
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                    Spacer()
                }
            }
            PhoneFrame {
                VStack {
                    Spacer()
                    Text("Notch").textStyle(.labelMd600)
                    Spacer()
                }
            }
            .notch(.notch)
            .bezel(.primary)
        }
        .frame(height: 420)
        .padding()
    }
    .background(theme.background(.bgSecondaryLight))
}
