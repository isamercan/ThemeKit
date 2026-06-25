//
//  ComponentUsage.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Carries a per-component usage snippet (set by the registry) down to the
//  ComponentStage, which renders a copyable "Usage" code card.
//

import SwiftUI

private struct ComponentUsageKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var componentUsage: String? {
        get { self[ComponentUsageKey.self] }
        set { self[ComponentUsageKey.self] = newValue }
    }
}
