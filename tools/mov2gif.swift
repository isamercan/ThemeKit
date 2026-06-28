#!/usr/bin/env swift
//
//  mov2gif.swift — convert a screen recording (.mov) to an animated GIF using
//  AVFoundation + ImageIO, so the recording pipeline needs no ffmpeg.
//
//      swift Tools/mov2gif.swift <input.mov> <output.gif> [fps] [maxWidth] [start] [end]
//
//  start/end (seconds) trim the clip; defaults capture the whole thing.
//

import AVFoundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: mov2gif <in.mov> <out.gif> [fps] [maxWidth] [start] [end]\n".utf8))
    exit(2)
}
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let fps = args.count > 3 ? (Double(args[3]) ?? 12) : 12
let maxWidth = args.count > 4 ? (Double(args[4]) ?? 480) : 480

let asset = AVURLAsset(url: input)
let total = CMTimeGetSeconds(asset.duration)
let start = args.count > 5 ? (Double(args[5]) ?? 0) : 0
let end = args.count > 6 ? (Double(args[6]) ?? total) : total
guard end > start else { FileHandle.standardError.write(Data("empty range\n".utf8)); exit(1) }

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.maximumSize = CGSize(width: maxWidth, height: maxWidth * 4)

let frameCount = max(1, Int((end - start) * fps))
guard let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
    FileHandle.standardError.write(Data("could not create GIF\n".utf8)); exit(1)
}
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / fps]] as CFDictionary

var written = 0
for i in 0..<frameCount {
    let t = CMTime(seconds: start + Double(i) / fps, preferredTimescale: 600)
    if let cg = try? gen.copyCGImage(at: t, actualTime: nil) {
        CGImageDestinationAddImage(dest, cg, frameProps)
        written += 1
    }
}
guard written > 0, CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("no frames extracted\n".utf8)); exit(1)
}
print("✓ \(output.lastPathComponent) — \(written) frames @ \(Int(fps))fps")
