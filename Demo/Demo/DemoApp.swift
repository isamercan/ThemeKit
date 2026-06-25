//
//  DemoApp.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI
import GlobalUIComponents

@main
struct DemoApp: App {
    @StateObject private var themeStore = DemoThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeStore)
                .feedbackHost()       // installs the shared FeedbackPresenter + overlays
                // env-only (no root rebuild) so the in-session Configurator sheet
                // isn't torn down mid-edit; screens observe Theme via @ThemeContext.
                .globalUITheme(reactToRuntimeChanges: false)
        }
    }
}
