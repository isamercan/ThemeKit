//
//  SheetHeader.swift
//  ThemeKit
//
//  Organism. A modal / sheet navigation header — an optional back (‹), a centered
//  title (+ subtitle), an optional close (✕) or custom trailing, and an optional
//  bottom progress line for multi-step flows. Token-bound. (Distinct from the
//  bottom tab ``NavigationBar``.)
//
//  ```swift
//  SheetHeader("Passengers").onBack { pop() }.onClose { dismiss() }.progress(0.4)
//  ```
//

import SwiftUI

public struct SheetHeader: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let title: String
    // Content/appearance — mutated only through the modifiers below (R2).
    private var subtitle: String?
    private var onBack: (() -> Void)?
    private var onClose: (() -> Void)?
    private var progress: Double?
    private var trailingSlot: AnyView?
    private var showsDivider = true
    private var accent: SemanticColor?

    public init(_ title: String) { self.title = title }   // R1

    private var accentBase: Color { (accent ?? .primary).base }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sideSlot(alignment: .leading) {
                    if let onBack {
                        iconButton("chevron.left", onBack).mirrorsInRTL()
                    }
                }
                Spacer(minLength: 4)
                VStack(spacing: 1) {
                    Text(title).textStyle(.labelLg700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                    if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
                }
                Spacer(minLength: 4)
                sideSlot(alignment: .trailing) {
                    if let trailingSlot { trailingSlot }
                    else if let onClose { iconButton("xmark", onClose) }
                }
            }
            .padding(.horizontal, density.scale(Theme.SpacingKey.sm.value))
            .frame(height: 56)

            if let progress {
                progressBar(progress)
            } else if showsDivider {
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
            }
        }
        .background(theme.background(.bgElevatorPrimary))
    }

    private func sideSlot<V: View>(alignment: Alignment, @ViewBuilder _ content: () -> V) -> some View {
        content().frame(width: 44, height: 44, alignment: alignment)
    }

    private func iconButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.text(.textPrimary)).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon == "xmark" ? "Close" : "Back")
    }

    private func progressBar(_ value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.border(.borderPrimary))
                Rectangle().fill(accentBase).frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SheetHeader {
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    /// Adds a leading back (‹) button.
    func onBack(_ action: @escaping () -> Void) -> Self { copy { $0.onBack = action } }
    /// Adds a trailing close (✕) button.
    func onClose(_ action: @escaping () -> Void) -> Self { copy { $0.onClose = action } }
    /// A bottom progress line (0…1) for a multi-step flow (replaces the divider).
    func progress(_ value: Double?) -> Self { copy { $0.progress = value } }
    /// A fully custom trailing accessory (replaces the close button).
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.trailingSlot = AnyView(content()) } }
    /// Draw the bottom hairline divider (default on; ignored when a progress bar is shown).
    func showsDivider(_ on: Bool) -> Self { copy { $0.showsDivider = on } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 20) {
        SheetHeader("Passengers").onBack { }.onClose { }
        SheetHeader("Payment").subtitle("Step 3 of 4").onBack { }.onClose { }.progress(0.75)
        SheetHeader("UcuzaBilet").onClose { }
    }
}
