//
//  CornerRadiusModifier.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Applies a theme-driven corner radius from the active theme's radius tokens.
//

import SwiftUI

public struct CornerRadiusModifier: ViewModifier {
    let key: Theme.RadiusKey

    public func body(content: Content) -> some View {
        content.clipShape(RoundedRectangle(cornerRadius: key.value, style: .continuous))
    }
}

public extension View {
    /// Clips the view with a radius token, e.g. `.cornerRadius(.rdBase)`.
    func cornerRadius(_ key: Theme.RadiusKey) -> some View {
        modifier(CornerRadiusModifier(key: key))
    }
}
