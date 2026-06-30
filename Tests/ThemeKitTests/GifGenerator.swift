//
//  GifGenerator.swift
//  ThemeKitTests
//
//  Builds short animated-GIF entrance previews for the custom SwiftUI overlays —
//  components that present over a scrim and so can't be shown as a single static
//  frame. Each overlay's *presented* state is rendered via a real offscreen
//  NSWindow (the same hosted path the screenshot generator uses), then a fade+scale
//  entrance is synthesised in Core Graphics and encoded to Screenshots/<Name>.gif.
//
//  Opt-in (GENERATE_SCREENSHOTS=1), macOS-only, no simulator. Writes
//  Screenshots/gifs.tsv so the README script can embed the GIFs.
//
//  NOT covered: native presentations (SelectBox `Menu`, BottomSheet `.sheet`) and
//  presenter/host overlays (Tour, Feedback) — those draw outside the SwiftUI view
//  tree (OS-owned) and can only be captured by screen-recording the live Demo app.
//

#if os(macOS)
import XCTest
import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import ThemeKit

@available(macOS 13.0, *)
@MainActor
final class GifGenerator: XCTestCase {

    private var outDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Screenshots", isDirectory: true)
    }

    private var names: [String] = []

    func testGenerateOverlayGIFs() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GENERATE_SCREENSHOTS"] == "1",
            "Set GENERATE_SCREENSHOTS=1 to render overlay GIFs."
        )
        Theme.shared.loadTheme(named: "defaultTheme")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        gif("Dialog", Color.clear.frame(width: 360, height: 300)
            .dialog(isPresented: .constant(true), title: "Delete account?",
                    message: "This action cannot be undone.", primaryTitle: "Delete",
                    onPrimary: {}, secondaryTitle: "Cancel", onSecondary: {}, kind: .error))

        gif("Drawer", Color.clear.frame(width: 380, height: 300)
            .drawer(isPresented: .constant(true), edge: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Menu").textStyle(.headingSm).padding(.bottom, 4)
                    ListRow("My account", action: {}).icon("person.circle")
                    ListRow("Reservations", action: {}).icon("calendar")
                    ListRow("Settings", action: {}).icon("gearshape")
                }.padding()
            })

        gif("Popconfirm", VStack {
            Spacer()
            ThemeButton("Delete") {}.icon(leading: "trash").color(.error).variant(.soft)
        }
            .frame(width: 320, height: 240)
            .popconfirm(isPresented: .constant(true), title: "Delete this item?",
                        message: "This action cannot be undone.", confirmTitle: "Delete",
                        cancelTitle: "Cancel", edge: .top, onConfirm: {}))

        gif("AlertToast", AlertToast("Saved successfully", message: "Your changes were stored.",
                                     type: .success, onClose: {}).frame(width: 360).padding(.vertical, 12))

        gif("Tooltip", Icon(systemName: "info.circle", size: .lg, color: Theme.shared.foreground(.fgHero))
            .tooltip("Helpful tip", isPresented: .constant(true), edge: .bottom)
            .padding(.vertical, 44).padding(.horizontal, 60))

        let tsv = names.map { "Organisms\t\($0)" }.joined(separator: "\n") + "\n"
        try tsv.write(to: outDir.appendingPathComponent("gifs.tsv"), atomically: true, encoding: .utf8)
    }

    // MARK: Render + encode

    private func gif(_ name: String, _ view: some View) {
        guard let open = hostedCGImage(view.padding(16).background(Theme.shared.background(.bgWhite))) else {
            XCTFail("\(name): no presented frame"); return
        }
        let frames = entranceFrames(open)
        let url = outDir.appendingPathComponent("\(name).gif")
        encodeGIF(frames, frameDelay: 0.05, to: url)
        names.append(name)
    }

    /// Host the view in a borderless offscreen window and cache its rendered layer,
    /// so the overlay's scrim + custom controls draw (drop first responder for a
    /// resting capture). Mirrors ScreenshotGenerator.hostedCGImage.
    private func hostedCGImage(_ view: some View) -> CGImage? {
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        guard size.width > 1, size.height > 1 else { return nil }
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        window.makeFirstResponder(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        return rep.cgImage
    }

    /// closed (white) → fade + scale the presented frame in → hold open → fade out.
    private func entranceFrames(_ open: CGImage) -> [CGImage] {
        let steps = 12
        var frames: [CGImage] = []
        func compose(scale: CGFloat, alpha: CGFloat) -> CGImage? {
            let w = open.width, h = open.height
            guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let dw = CGFloat(w) * scale, dh = CGFloat(h) * scale
            ctx.setAlpha(alpha)
            ctx.draw(open, in: CGRect(x: (CGFloat(w) - dw) / 2, y: (CGFloat(h) - dh) / 2, width: dw, height: dh))
            return ctx.makeImage()
        }
        // Start on the OPEN state so the GIF's poster/first frame shows the overlay
        // (not a blank frame), then loop: hold open → fade out → fade in.
        if let o = compose(scale: 1, alpha: 1) { frames += Array(repeating: o, count: 18) }  // hold open (poster)
        for i in stride(from: steps, through: 1, by: -2) {                             // fade out
            let p = CGFloat(i) / CGFloat(steps)
            if let f = compose(scale: 0.94 + 0.06 * p, alpha: p) { frames.append(f) }
        }
        if let c = compose(scale: 0.94, alpha: 0) { frames += [c, c] }                 // brief closed hold
        for i in 1...steps {                                                            // fade in (entrance)
            let t = CGFloat(i) / CGFloat(steps)
            let p = 1 - pow(1 - t, 3)                                                   // ease-out
            if let f = compose(scale: 0.94 + 0.06 * p, alpha: p) { frames.append(f) }
        }
        return frames
    }

    private func encodeGIF(_ frames: [CGImage], frameDelay: Double, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            XCTFail("GIF destination failed"); return
        }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameDelay]] as CFDictionary
        for f in frames { CGImageDestinationAddImage(dest, f, frameProps) }
        CGImageDestinationFinalize(dest)
    }
}
#endif
