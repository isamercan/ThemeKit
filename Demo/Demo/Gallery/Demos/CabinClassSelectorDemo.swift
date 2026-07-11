// REGISTER: CabinClassSelector · deep-link "CabinClassSelector" · molecule · isNew
//
//  CabinClassSelectorDemo.swift
//  Demo
//
//  Interactive demo page for the ThemeKitTravel CabinClassSelector molecule
//  (F2.1 · §9.5) — segmented / chips / list variants over the CabinClass model.
//

import SwiftUI
import ThemeKit
import ThemeKitTravel

struct CabinClassSelectorDemo: View {
    @State private var cabin: CabinClass = .economy
    @State private var variantIdx = 0   // 0 segmented, 1 chips, 2 list
    @State private var glyphs = false
    @State private var domesticOnly = false
    @State private var accented = false
    @State private var readOnly = false
    @State private var enabled = true

    private var variant: CabinClassVariant {
        switch variantIdx {
        case 1: .chips
        case 2: .list
        default: .segmented
        }
    }
    private var variantName: String {
        switch variantIdx {
        case 1: "chips"
        case 2: "list"
        default: "segmented"
        }
    }

    var body: some View {
        ComponentStage("CabinClassSelector", inspector: [
            ("selection", cabin.label), ("variant", variantName), ("glyphs", "\(glyphs)"),
        ]) {
            CabinClassSelector(selection: $cabin)
                .variant(variant)
                .showsGlyphs(glyphs)
                .classes(domesticOnly ? [.economy, .business] : CabinClass.allCases)
                .accent(accented ? .success : nil)
                .readOnly(readOnly)
                .disabled(!enabled)
        } knobs: {
            Picker("Variant", selection: $variantIdx) {
                Text("Segmented").tag(0); Text("Chips").tag(1); Text("List").tag(2)
            }.pickerStyle(.segmented)
            Toggle("Cabin glyphs (SF Symbols)", isOn: $glyphs)
            Toggle("Domestic subset (economy + business)", isOn: $domesticOnly)
            Toggle("Accent (.success)", isOn: $accented)
            Toggle("Read-only (blocks selection, normal chrome)", isOn: $readOnly)
            Toggle("Enabled", isOn: $enabled)
        }
    }
}
