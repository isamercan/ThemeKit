//
//  Barcode.swift
//  ThemeKit
//
//  A 1-D barcode (Code 128) rendered via CoreImage — no dependency. High-contrast for
//  scanning; stretches to fill its width. Reused by BoardingPass / TicketCard.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

/// A token-sized (but high-contrast) Code 128 barcode with an optional caption.
///
/// ```swift
/// Barcode("9824097217421298").height(48).showsValue()
/// ```
public struct Barcode: View {
    private let value: String
    // Appearance — mutated only through the modifiers below (R2).
    private var height: CGFloat = 56
    private var showsValue: Bool = false

    public init(_ value: String) {   // R1 — content
        self.value = value
    }

    public var body: some View {
        VStack(spacing: 6) {
            Group {
                if let cg = Self.render(value) {
                    Image(decorative: cg, scale: 1)
                        .interpolation(.none)
                        .resizable()
                } else {
                    Image(systemName: "barcode")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            if showsValue {
                Text(value)
                    .font(.system(.footnote, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Barcode \(value)")
    }

    private static func render(_ string: String) -> CGImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage else { return nil }
        return CoreImageContext.shared.createCGImage(output, from: output.extent)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Barcode {
    /// Bar height in points (default 56).
    func height(_ points: CGFloat) -> Self { copy { $0.height = points } }
    /// Shows the value as a monospaced caption under the bars.
    func showsValue(_ on: Bool = true) -> Self { copy { $0.showsValue = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    Barcode("9824097217421298").height(56).showsValue().padding()
}
