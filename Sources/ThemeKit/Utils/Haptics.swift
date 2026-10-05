//
//  Haptics.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Lightweight haptic feedback helpers (iOS). No-ops where UIKit haptics aren't
//  available (e.g. macOS). Used by the button family for tactile press / success.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum Haptics {
    /// A light tap — for button presses / selections.
    public static func tap() {
        #if canImport(UIKit) && os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// The selection tick — for a control's value changing (a switch, a box, a radio) and each
    /// beat of ``SwiftUI/View/shake(trigger:)``.
    public static func selection() {
        #if canImport(UIKit) && os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// A medium thud — for stronger confirmations.
    public static func impact() {
        #if canImport(UIKit) && os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// Success notification — for completed actions.
    public static func success() {
        #if canImport(UIKit) && os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Warning / error notification.
    public static func warning() {
        #if canImport(UIKit) && os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
