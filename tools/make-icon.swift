// Draws the app icon: a chunky tilted "B" with a "no play" sticker on it. Blocker: no reels.
// Run: swift tools/make-icon.swift Blocker/Assets.xcassets/AppIcon.appiconset/AppIcon.png
// (Shapes only, no fonts or SF Symbols, so there's nothing to license.)
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

func color(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255, CGFloat(hex & 0xff) / 255, 1,
    ])!
}

let yellow = color(0xFFD43B)
let ink = color(0x14110F)
let red = color(0xE5383B)
let white = color(0xFFFFFF)

func capsule(_ rect: CGRect) -> CGPath {
    let radius = min(rect.width, rect.height) / 2
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fill(_ path: CGPath, _ fill: CGColor) {
    ctx.setFillColor(fill)
    ctx.addPath(path)
    ctx.fillPath()
}

// Sunny background, a little warmer at the bottom.
let background = CGGradient(colorsSpace: space, colors: [color(0xFFE066), color(0xFFB703)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(background, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 1024),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// The B and the sticker's gap ring go in their own layer, so the holes can be cut out
// and the background gradient shows through them.
let center = CGPoint(x: 772, y: 786) // the sticker
func circle(_ radius: CGFloat) -> CGRect {
    CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
}

ctx.beginTransparencyLayer(auxiliaryInfo: nil)

// The B: a stem and two bowls, tilted for attitude.
ctx.saveGState()
ctx.translateBy(x: 470, y: 505)
ctx.rotate(by: -8 * .pi / 180)
ctx.scaleBy(x: 0.9, y: 0.9)
ctx.translateBy(x: -480, y: -510)
fill(CGPath(roundedRect: CGRect(x: 250, y: 170, width: 170, height: 680), cornerWidth: 48, cornerHeight: 48, transform: nil), ink)
fill(CGPath(rect: CGRect(x: 300, y: 170, width: 140, height: 680), transform: nil), ink) // square off the stem's right side
fill(capsule(CGRect(x: 250, y: 170, width: 410, height: 350)), ink)   // top bowl
fill(capsule(CGRect(x: 250, y: 470, width: 460, height: 380)), ink)   // bottom bowl, bigger
ctx.setBlendMode(.clear)
fill(capsule(CGRect(x: 420, y: 290, width: 120, height: 110)), ink)   // top hole
fill(capsule(CGRect(x: 420, y: 595, width: 150, height: 130)), ink)   // bottom hole
ctx.restoreGState()

// Gap between the sticker and the B.
ctx.setBlendMode(.clear)
ctx.fillEllipse(in: circle(186))
ctx.setBlendMode(.normal)
ctx.endTransparencyLayer()

// The sticker: a "no play" sign slapped on the B's corner.
ctx.setFillColor(white)
ctx.fillEllipse(in: circle(164))

let play = CGMutablePath() // reel / play symbol
play.move(to: CGPoint(x: center.x - 44, y: center.y - 70))
play.addLine(to: CGPoint(x: center.x + 76, y: center.y))
play.addLine(to: CGPoint(x: center.x - 44, y: center.y + 70))
play.closeSubpath()
fill(play, ink)

ctx.setStrokeColor(red)
ctx.setLineWidth(40)
ctx.strokeEllipse(in: circle(140))
ctx.saveGState()
ctx.addEllipse(in: circle(140))
ctx.clip()
ctx.setLineCap(.butt)
ctx.move(to: CGPoint(x: center.x - 140, y: center.y - 140))
ctx.addLine(to: CGPoint(x: center.x + 140, y: center.y + 140))
ctx.strokePath()
ctx.restoreGState()

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("couldn't write \(output.path)") }
print("wrote \(output.path)")
