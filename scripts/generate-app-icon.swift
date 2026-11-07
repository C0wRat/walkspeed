#!/usr/bin/env swift
// Renders the WalkSpeed app icon: the app's speed ring, with its limit notch,
// around a walking figure.
//
// Usage:
//   swift scripts/generate-app-icon.swift WalkSpeed/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import AppKit

let side = 1_024
// Slightly below the middle, so the ring's opening at the bottom doesn't
// make the icon look top-heavy.
let center = CGPoint(x: side / 2, y: side / 2 - 36)
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

guard
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        // App icons must not have an alpha channel.
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
else {
    fatalError("Couldn't create a drawing context.")
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

// Background: a diagonal teal gradient.
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(0.18, 0.82, 0.62), color(0.02, 0.40, 0.42)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: side),
    end: CGPoint(x: side, y: 0),
    options: []
)

// The ring covers 270°, open at the bottom, like the gauge in the app.
// Core Graphics measures angles anticlockwise from the x-axis, y pointing up.
let radius: CGFloat = 340
let lineWidth: CGFloat = 76

func angle(atFraction fraction: CGFloat) -> CGFloat {
    (225 - 270 * fraction) * .pi / 180
}

func strokeArc(from start: CGFloat, to end: CGFloat, color strokeColor: CGColor) {
    context.addArc(
        center: center,
        radius: radius,
        startAngle: angle(atFraction: start),
        endAngle: angle(atFraction: end),
        clockwise: true
    )
    context.setStrokeColor(strokeColor)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.strokePath()
}

strokeArc(from: 0, to: 1, color: color(1, 1, 1, 0.25))
strokeArc(from: 0, to: 0.52, color: color(1, 1, 1))

// The limit notch.
let limitAngle = angle(atFraction: 0.68)
context.saveGState()
context.translateBy(x: center.x, y: center.y)
context.rotate(by: limitAngle)
let notch = CGRect(x: radius - lineWidth * 0.95, y: -21, width: lineWidth * 1.9, height: 42)
context.addPath(CGPath(roundedRect: notch, cornerWidth: 21, cornerHeight: 21, transform: nil))
context.setFillColor(color(1.0, 0.62, 0.20))
context.fillPath()
context.restoreGState()

// The walking figure, drawn with SF Symbols.
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let configuration = NSImage.SymbolConfiguration(pointSize: 370, weight: .bold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
guard
    let symbol = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
else {
    fatalError("Couldn't load the figure.walk symbol.")
}
let symbolRect = CGRect(
    x: center.x - symbol.size.width / 2,
    y: center.y - symbol.size.height / 2,
    width: symbol.size.width,
    height: symbol.size.height
)
symbol.draw(in: symbolRect)
NSGraphicsContext.current = nil

// Save as PNG.
guard
    let image = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: output) as CFURL,
        "public.png" as CFString,
        1,
        nil
    )
else {
    fatalError("Couldn't create \(output).")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Couldn't write \(output).")
}
print("Wrote \(output)")
