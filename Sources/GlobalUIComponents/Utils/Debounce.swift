//
//  Debounce.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Debounced change handler — fires `perform` only after `seconds` of no further
//  changes (each new value cancels the pending call). Used by typeahead
//  search/autocomplete to throttle async work.
//

import SwiftUI

public extension View {
    func onDebouncedChange<V: Equatable>(of value: V, for seconds: Double, perform: @escaping (V) -> Void) -> some View {
        task(id: value) {
            guard seconds > 0 else { perform(value); return }
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                perform(value)
            } catch {
                // Cancelled because `value` changed again — drop this stale call.
            }
        }
    }
}
