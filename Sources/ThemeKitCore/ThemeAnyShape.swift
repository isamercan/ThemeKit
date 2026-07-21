//
//  ThemeAnyShape.swift
//  ThemeKitCore
//
//  iOS 15.6-floor compat (ADR-0007 §D2 rule 1 — single-path): SwiftUI's
//  `AnyShape` type eraser is iOS 16-only, so this is the one shape eraser the
//  package uses, on every OS. Capability-identical for everything the library
//  does through it (`fill`, `stroke`, `clipShape`, `contentShape`,
//  `background(_:in:)`), and — like `SwiftUI.AnyShape` — erasure drops the
//  wrapped shape's `Animatable` data (no cross-shape morphing); no call site
//  animated through the eraser before.
//
//  Deliberately NOT named `AnyShape`: ThemeKit/ThemeKitTravel see both SwiftUI
//  and (transitively) ThemeKitCore, and two imported modules declaring the
//  same type name would make every unqualified `AnyShape` reference ambiguous
//  on the iOS 16+ SDK. A distinct name compiles cleanly at both the 15.6
//  floor and the current `.v17` manifest. When the deployment floor rises past
//  16 this file is a deletion-checklist entry (ADR-0007 §D6): rename call
//  sites back to `AnyShape` and delete it.
//

import SwiftUI

/// A type-erased `Shape`, usable on the iOS 15.6 floor (`SwiftUI.AnyShape`
/// is iOS 16+). Wrap any concrete shape to store heterogeneous shapes behind
/// one type — the package-wide replacement for `SwiftUI.AnyShape`
/// (ADR-0007 §D2 rule 1).
public struct ThemeAnyShape: Shape, @unchecked Sendable {
    // `@unchecked`: the wrapped shape is immutable (`let`) and every SwiftUI
    // `Shape` is a value type — mirrors `SwiftUI.AnyShape`'s own
    // `@unchecked Sendable`.
    private let base: any Shape

    /// Wraps `shape`, erasing its concrete type.
    public init<S: Shape>(_ shape: S) {
        self.base = shape
    }

    public func path(in rect: CGRect) -> Path {
        base.path(in: rect)
    }

    /// Forwards the wrapped shape's ideal-size answer where the concept exists
    /// (iOS 16+), so erasure never changes how a shape sizes when used bare.
    @available(iOS 16.0, macOS 13.0, *)
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        base.sizeThatFits(proposal)
    }

    /// Forwards the wrapped shape's RTL behavior where the concept exists
    /// (iOS 17+), so erasure never changes how a shape mirrors — identical to
    /// the system eraser. Below iOS 17, custom shapes have no direction
    /// behavior; same as every other custom `Shape` in the package.
    @available(iOS 17.0, macOS 14.0, *)
    public var layoutDirectionBehavior: LayoutDirectionBehavior {
        base.layoutDirectionBehavior
    }
}
