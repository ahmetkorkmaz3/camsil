#!/usr/bin/env swift
// Draws the 1024 px app icon: a dusty window pane with one clean, shiny wipe.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

guard CommandLine.arguments.count == 2 else {
    print("Usage: swift scripts/make-icon.swift <output.png>")
    exit(1)
}

let size = 1024.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: an 824 px rounded square in the 1024 px canvas.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor(red: 0.07, green: 0.36, blue: 0.75, alpha: 1).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
tilePath.addClip()

// Clean glass: a deep blue to sky blue gradient.
NSGradient(starting: NSColor(red: 0.05, green: 0.33, blue: 0.72, alpha: 1),
           ending: NSColor(red: 0.42, green: 0.78, blue: 0.98, alpha: 1))!.draw(in: tile, angle: 70)

// Dust over the whole pane, with a fixed seed so each run gives the same icon.
var seed: UInt64 = 0x00C0_FFEE
func random() -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double(seed >> 11) / Double(1 << 53)
}
let dust = NSBezierPath(rect: tile)
let wipe = NSBezierPath()
wipe.lineWidth = 170
wipe.lineCapStyle = .round
wipe.move(to: NSPoint(x: 230, y: 330))
wipe.curve(to: NSPoint(x: 800, y: 700), controlPoint1: NSPoint(x: 380, y: 760), controlPoint2: NSPoint(x: 620, y: 380))
let wipeArea = NSBezierPath(cgPath: wipe.cgPath.copy(strokingWithWidth: 170, lineCap: .round, lineJoin: .round, miterLimit: 10))
dust.append(wipeArea.reversed)
dust.windingRule = .evenOdd

NSGraphicsContext.saveGraphicsState()
dust.addClip()
NSColor(red: 0.78, green: 0.72, blue: 0.6, alpha: 0.55).setFill()
tile.fill()
for _ in 0..<900 {
    let r = 3 + random() * 14
    let spot = NSRect(x: 100 + random() * 824, y: 100 + random() * 824, width: r, height: r)
    NSColor(red: 0.55, green: 0.48, blue: 0.38, alpha: 0.15 + random() * 0.3).setFill()
    NSBezierPath(ovalIn: spot).fill()
}
NSGraphicsContext.restoreGraphicsState()

// Wet rim on the edge of the wipe.
NSColor.white.withAlphaComponent(0.35).setStroke()
wipeArea.lineWidth = 6
wipeArea.stroke()

// Two shine lines on the clean glass.
ctx.setLineCap(.round)
for (offset, width) in [(0.0, 34.0), (70.0, 16.0)] {
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.75).cgColor)
    ctx.setLineWidth(width)
    ctx.move(to: CGPoint(x: 430 + offset, y: 470))
    ctx.addLine(to: CGPoint(x: 560 + offset, y: 600))
    ctx.strokePath()
}

// Sparkle.
let star = NSBezierPath()
let c = NSPoint(x: 735, y: 760)
for i in 0..<8 {
    let a = Double(i) * .pi / 4 + .pi / 2
    let r = i % 2 == 0 ? 70.0 : 16.0
    let p = NSPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
    if i == 0 { star.move(to: p) } else { star.line(to: p) }
}
star.close()
NSColor.white.setFill()
star.fill()

NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
