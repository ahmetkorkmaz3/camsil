#!/usr/bin/env swift
// Usage: swift scripts/cutout.swift <input.png> <output.png>
// Makes the white background transparent, crops to the bottle and scales it to 600 px height.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("Usage: swift scripts/cutout.swift <input.png> <output.png>")
    exit(1)
}

let w = image.width, h = image.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let space = CGColorSpaceCreateDeviceRGB()
let info = CGImageAlphaInfo.premultipliedLast.rawValue
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: info)!
ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

func isWhite(_ i: Int) -> Bool { px[i] > 235 && px[i + 1] > 235 && px[i + 2] > 235 }

// Flood fill from every border pixel.
var background = [Bool](repeating: false, count: w * h)
var stack: [(Int, Int)] = []
for x in 0..<w { stack.append((x, 0)); stack.append((x, h - 1)) }
for y in 0..<h { stack.append((0, y)); stack.append((w - 1, y)) }
while let (x, y) = stack.popLast() {
    guard x >= 0, y >= 0, x < w, y < h else { continue }
    let k = y * w + x
    guard !background[k], isWhite(k * 4) else { continue }
    background[k] = true
    stack.append((x + 1, y)); stack.append((x - 1, y)); stack.append((x, y + 1)); stack.append((x, y - 1))
}

// Clear the background and soften the light edge pixels next to it.
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h {
    for x in 0..<w {
        let k = y * w + x, i = k * 4
        if background[k] {
            px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0
            continue
        }
        let touches = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
            let nx = x + dx, ny = y + dy
            return nx >= 0 && ny >= 0 && nx < w && ny < h && background[ny * w + nx]
        }
        if touches && (Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2])) / 3 > 200 {
            for c in 0..<4 { px[i + c] /= 2 }
        }
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    }
}

let full = ctx.makeImage()!
let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
let cropped = full.cropping(to: cropRect)!
let outH = 600
let outW = Int((Double(cropped.width) * Double(outH) / Double(cropped.height)).rounded())
let out = CGContext(data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info)!
out.interpolationQuality = .high
out.draw(cropped, in: CGRect(x: 0, y: 0, width: outW, height: outH))

let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, out.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("crop (image px, top-left): x=\(minX) y=\(minY) w=\(cropRect.width) h=\(cropRect.height) -> \(outW)x\(outH)")
