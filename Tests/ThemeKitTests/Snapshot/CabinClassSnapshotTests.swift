//
//  CabinClassSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the ThemeKitTravel CabinClassSelector
//  molecule (F2.1 · §9.5) — the three variants plus glyph/accent states.
//  iOS-only + opt-in (see SnapshotSupport.swift).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
import ThemeKit
import ThemeKitTravel

@MainActor
final class CabinClassSnapshotTests: SnapshotTestCase {

    func testCabinClassSelector_states() {
        assertComponentSnapshot(VStack(alignment: .leading, spacing: 16) {
            CabinClassSelector(selection: .constant(.economy))
            CabinClassSelector(selection: .constant(.business)).showsGlyphs().accent(.success)
            CabinClassSelector(selection: .constant(.economy)).classes([.economy, .business])
            CabinClassSelector(selection: .constant(.premiumEconomy)).variant(.chips).showsGlyphs()
            CabinClassSelector(selection: .constant(.first)).variant(.list)
        })
    }
}
#endif
