//
//  Grid.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Grid layout tokens — column helpers with token-based gutters / margins.
//

import SwiftUI

public enum GridLayout {
    /// Screen edge margin.
    public static var margin: CGFloat { Theme.SpacingKey.md.value }   // 16
    /// Default gutter between columns.
    public static var gutter: CGFloat { Theme.SpacingKey.sm.value }   // 8

    /// Flexible columns for a `LazyVGrid`, gutter from the spacing scale.
    public static func columns(_ count: Int, gutter: Theme.SpacingKey = .sm) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gutter.value), count: max(1, count))
    }

    /// Adaptive columns with a minimum item width.
    public static func adaptive(minWidth: CGFloat, gutter: Theme.SpacingKey = .sm) -> [GridItem] {
        [GridItem(.adaptive(minimum: minWidth), spacing: gutter.value)]
    }
}
