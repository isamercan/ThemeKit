//
//  Backdrop.swift
//  ThemeKit
//
//  Atom. The standard modal scrim shared by every presenter (Dialog, Drawer,
//  Tour): a `bgBackdrop` token fill that ignores the safe area, fades only
//  (never moves — RTL-agnostic, Reduce-Motion safe by construction), and takes
//  a `fade` progress hook so drag-to-dismiss can dim it with the finger.
//
//  The fill reads `Theme.backdrop`, which falls back to a neutral 40% dim when
//  the active theme predates the `background.bg-backdrop` token — a consumer
//  theme can never render an invisible scrim.
//
//  Three styles (HeroUI Modal's `backdrop` prop) via `.material(_:)`: `.dim`
//  (the token fill, default), `.blur` (a translucent `Material` that frosts the
//  content behind — falls back to `.dim` under Reduce Transparency), and
//  `.transparent` (no visual dim, still tap-catching so scrim-tap dismissal
//  keeps working).
//

import SwiftUI

/// The look of a ``Backdrop`` scrim — HeroUI Modal's `backdrop` prop.
public enum BackdropStyle: String, CaseIterable, Sendable {
    /// The `bgBackdrop` token dim (black @ 40% light / 55% dark). The default.
    case dim
    /// A translucent `Material` that frosts the content behind the scrim, with a
    /// light token dim on top for legibility. Degrades to `.dim` under Reduce
    /// Transparency (no translucency) — the card can never lose contrast.
    case blur
    /// No visual dim at all — the card floats over untinted content. The scrim
    /// still fills the screen and catches taps, so scrim-tap dismissal works.
    case transparent
}

/// The standard modal scrim: `bgBackdrop` fill, fade-only, `.ignoresSafeArea()`.
///
/// - `fade` is a 0…1 progress hook (1 = resting dim) for drag-to-dismiss.
/// - `.material(_:)` picks the `.dim` / `.blur` / `.transparent` style.
/// - `cutout` optionally punches a spotlight hole through the scrim (Tour);
///   it is applied *before* the safe-area expansion so cutout coordinates stay
///   in the presenter's own space.
///
/// Tap handling, transitions, and accessibility semantics stay at the call
/// site — presenters differ in how (and whether) the scrim dismisses.
struct Backdrop<Cutout: View>: View {
    /// Dismiss-drag progress: 1 at rest, toward 0 as the presented surface is
    /// dragged away.
    var fade: Double = 1
    /// Scrim look (`.dim` by default) — mutate via `.material(_:)`.
    var style: BackdropStyle = .dim
    /// Shape(s) punched out of the scrim (spotlight). `EmptyView` = solid scrim.
    @ViewBuilder var cutout: () -> Cutout

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if Cutout.self == EmptyView.self {
            fill.ignoresSafeArea()
        } else {
            fill
                .mask { Rectangle().overlay { cutout().blendMode(.destinationOut) } }
                .ignoresSafeArea()
        }
    }

    @ViewBuilder private var fill: some View {
        switch style {
        case .dim:
            theme.backdrop.opacity(fade)
        case .blur:
            if reduceTransparency {
                // No translucency permitted — the plain token dim instead.
                theme.backdrop.opacity(fade)
            } else {
                // Frost the content behind, then a light token dim keeps the card
                // legible over busy imagery. `fade` dims the whole scrim as the
                // card is dragged away.
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay(theme.backdrop.opacity(0.5))
                    .opacity(fade)
            }
        case .transparent:
            // Untinted but still full-bleed and hit-testable (scrim-tap dismiss).
            Color.clear
        }
    }
}

extension Backdrop {
    /// Selects the scrim style (`.dim` / `.blur` / `.transparent`). Copy-on-write.
    func material(_ style: BackdropStyle) -> Self {
        var copy = self
        copy.style = style
        return copy
    }
}

extension Backdrop where Cutout == EmptyView {
    /// A solid scrim with no spotlight cutout (Dialog, Drawer).
    init(fade: Double = 1) {
        self.init(fade: fade, cutout: { EmptyView() })
    }
}

#Preview("Backdrop — resting / faded / cutout") {
    HStack(spacing: Theme.SpacingKey.md.value) {
        ZStack {
            Text(verbatim: "Resting")
            Backdrop()
        }
        ZStack {
            Text(verbatim: "Faded 0.35")
            Backdrop(fade: 0.35)
        }
        ZStack {
            Text(verbatim: "Cutout")
            Backdrop {
                Circle().frame(width: 64, height: 64)
            }
        }
    }
    .frame(height: 220)
}

#Preview("Backdrop — styles (dim / blur / transparent)") {
    HStack(spacing: Theme.SpacingKey.md.value) {
        ForEach(BackdropStyle.allCases, id: \.self) { style in
            ZStack {
                VStack(spacing: Theme.SpacingKey.xs.value) {
                    Icon(systemName: "photo").size(.xl)
                    Text(style.rawValue).textStyle(.labelSm600)
                }
                Backdrop().material(style)
                Text(verbatim: "Card")
                    .padding(Theme.SpacingKey.md.value)
                    .glassChrome(in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
            }
            .frame(maxWidth: .infinity)
        }
    }
    .frame(height: 220)
}

#Preview("Backdrop — dark") {
    ZStack {
        Text(verbatim: "Dark scrim")
        Backdrop()
    }
    .frame(height: 220)
    .preferredColorScheme(.dark)
}
