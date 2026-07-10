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

import SwiftUI

/// The standard modal scrim: `bgBackdrop` fill, fade-only, `.ignoresSafeArea()`.
///
/// - `fade` is a 0…1 progress hook (1 = resting dim) for drag-to-dismiss.
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
    /// Shape(s) punched out of the scrim (spotlight). `EmptyView` = solid scrim.
    @ViewBuilder var cutout: () -> Cutout

    @Environment(\.theme) private var theme

    var body: some View {
        if Cutout.self == EmptyView.self {
            fill.ignoresSafeArea()
        } else {
            fill
                .mask { Rectangle().overlay { cutout().blendMode(.destinationOut) } }
                .ignoresSafeArea()
        }
    }

    private var fill: some View {
        theme.backdrop.opacity(fade)
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

#Preview("Backdrop — dark") {
    ZStack {
        Text(verbatim: "Dark scrim")
        Backdrop()
    }
    .frame(height: 220)
    .preferredColorScheme(.dark)
}
