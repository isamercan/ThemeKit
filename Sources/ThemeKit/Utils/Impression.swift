//
//  Impression.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Lightweight impression / analytics hook — the dependency-free equivalent of
//  the reference `WidgetImpressionTracking` (env sink + a marker modifier). The
//  host supplies the sink; components mark trackable views with `.onImpression`.
//
//      RootView().impressionSink { print("seen:", $0.id, $0.index ?? -1) }
//      card.onImpression("hotel-card", index: i)
//

import SwiftUI

public struct ImpressionInfo: Sendable {
    public let id: String
    public let index: Int?
    public init(id: String, index: Int? = nil) { self.id = id; self.index = index }
}

private struct ImpressionSinkKey: EnvironmentKey {
    // `@Sendable` makes the default closure (and the environment value) concurrency-safe.
    static let defaultValue: @Sendable (ImpressionInfo) -> Void = { _ in }
}

public extension EnvironmentValues {
    var impressionSink: @Sendable (ImpressionInfo) -> Void {
        get { self[ImpressionSinkKey.self] }
        set { self[ImpressionSinkKey.self] = newValue }
    }
}

public extension View {
    /// Installs the app-wide impression sink (host analytics).
    func impressionSink(_ sink: @escaping @Sendable (ImpressionInfo) -> Void) -> some View {
        environment(\.impressionSink, sink)
    }

    /// Fires the impression sink once, the first time this view appears.
    func onImpression(_ id: String, index: Int? = nil) -> some View {
        modifier(ImpressionModifier(info: ImpressionInfo(id: id, index: index)))
    }
}

private struct ImpressionModifier: ViewModifier {
    let info: ImpressionInfo
    @Environment(\.impressionSink) private var sink
    @State private var fired = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !fired else { return }
            fired = true
            sink(info)
        }
    }
}
