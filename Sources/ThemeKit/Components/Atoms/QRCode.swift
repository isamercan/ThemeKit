//
//  QRCode.swift
//  ThemeKit
//
//  A scannable QR code rendered via CoreImage (CIQRCodeGenerator) — no dependency.
//  Kept high-contrast (dark modules on a light quiet zone) for reliable scanning, so
//  it is intentionally *not* theme-tinted. Reused by LoyaltyCard / BoardingPass.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

/// A token-sized (but high-contrast) QR code.
///
/// ```swift
/// QRCode("https://themekit.dev/pass/BID12025BKG").size(160)
/// ```
public struct QRCode: View {
    private let value: String
    // Appearance — mutated only through the modifiers below (R2).
    private var size: CGFloat = 160

    public init(_ value: String) {   // R1 — content
        self.value = value
    }

    public var body: some View {
        Group {
            if let cg = Self.render(value) {
                Image(decorative: cg, scale: 1)
                    .interpolation(.none)
                    .resizable()
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("QR code")
    }

    private static func render(_ string: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        return CoreImageContext.shared.createCGImage(output, from: output.extent)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension QRCode {
    /// Rendered size in points (square).
    func size(_ points: CGFloat) -> Self { copy { $0.size = points } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    QRCode("https://github.com/isamercan/ThemeKit").size(180).padding()
}
