//
//  ThemedHostingController.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// A themed `UIHostingController` for UIKit entry points.
///
/// Use this instead of `UIHostingController(rootView:)` when presenting SwiftUI
/// from a UIKit flow and the view tree needs app-wide access to `Theme.shared`.
/// Inside that tree, read the theme with `@ThemeContext`.
///
/// Example:
/// ```swift
/// let controller = ThemedHostingController(rootView: SomeComponentView())
/// navigationController?.pushViewController(controller, animated: true)
/// ```
public final class ThemedHostingController<Content: View>: UIHostingController<AnyView> {
    public init(rootView: Content) {
        super.init(rootView: AnyView(rootView.environment(Theme.shared)))
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }
}
#endif
