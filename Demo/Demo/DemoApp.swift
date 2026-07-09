//
//  DemoApp.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI
import UIKit
import ThemeKit

@main
struct DemoApp: App {
    @StateObject private var themeStore = DemoThemeStore()
    // Theme-wide micro-animation switch (toggled from the Configurator). Reduce
    // Motion always wins on top of this. Per-component override: `.microAnimations(false)`.
    @AppStorage("themekit.microAnimations") private var microAnimations = true

    var body: some Scene {
        WindowGroup {
            rootView
                .microAnimations(microAnimations)
                .environmentObject(themeStore)
                .feedbackHost()       // installs the shared FeedbackPresenter + overlays
                .sheetHost()          // installs the shared SheetPresenter
                .drawerHost()         // installs the shared DrawerPresenter
                // env-only (no root rebuild) so the in-session Configurator sheet
                // isn't torn down mid-edit; screens observe Theme via @ThemeContext.
                .themeKit(reactToRuntimeChanges: false)
        }
    }

    /// The Showcase collage is a wide-canvas (iPad) experience; on iPhone the Demo
    /// keeps its original tabbed catalog (``ContentView``).
    @ViewBuilder private var rootView: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            ShowcaseView()
        } else {
            ContentView()
        }
    }
}
