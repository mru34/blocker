// Draws the app icon: one post you keep, a bar where the scroll stops, and the faded feed you don't get.
// Run: swift tools/make-icon.swift Blocker/Assets.xcassets/AppIcon.appiconset/AppIcon.png
// (Drawn by hand because Apple's license doesn't allow SF Symbols in app icons.)
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)! // icons must be opaque
// Top-left origin, like the numbers below.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255, CGFloat(hex & 0xff) / 255, alpha,
    ])!
}

func fillRounded(_ rect: CGRect, radius: CGFloat, _ fill: CGColor) {
    ctx.setFillColor(fill)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
}

// Calm teal background.
let background = CGGradient(colorsSpace: space, colors: [color(0x2DD4BF), color(0x0F4C5C)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(background, start: CGPoint(x: 160, y: 0), end: CGPoint(x: 864, y: 1024),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// The post you keep: a white card with a photo.
let card = CGRect(x: 262, y: 150, width: 500, height: 380)
fillRounded(card, radius: 72, color(0xFFFFFF))
ctx.setFillColor(color(0x0F766E))
ctx.fillEllipse(in: CGRect(x: 604, y: 214, width: 84, height: 84)) // sun
let mountains = CGMutablePath()
mountains.move(to: CGPoint(x: 322, y: 470))
mountains.addLine(to: CGPoint(x: 452, y: 318))
mountains.addLine(to: CGPoint(x: 552, y: 430))
mountains.addLine(to: CGPoint(x: 616, y: 362))
mountains.addLine(to: CGPoint(x: 702, y: 470))
mountains.closeSubpath()
ctx.addPath(mountains)
ctx.fillPath()

// Where the scroll stops.
fillRounded(CGRect(x: 222, y: 598, width: 580, height: 60), radius: 30, color(0xFFFFFF))

// The endless feed you don't get, fading out.
fillRounded(CGRect(x: 262, y: 726, width: 500, height: 200), radius: 56, color(0xFFFFFF, 0.26))
fillRounded(CGRect(x: 262, y: 954, width: 500, height: 200), radius: 56, color(0xFFFFFF, 0.10))

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("couldn't write \(output.path)") }
print("wrote \(output.path)")
