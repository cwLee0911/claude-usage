import AppKit
import Foundation

struct IconSlot {
    let filename: String
    let pixels: Int
}

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("claude-usage/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

let slots = [
    IconSlot(filename: "icon_16x16.png", pixels: 16),
    IconSlot(filename: "icon_16x16@2x.png", pixels: 32),
    IconSlot(filename: "icon_32x32.png", pixels: 32),
    IconSlot(filename: "icon_32x32@2x.png", pixels: 64),
    IconSlot(filename: "icon_128x128.png", pixels: 128),
    IconSlot(filename: "icon_128x128@2x.png", pixels: 256),
    IconSlot(filename: "icon_256x256.png", pixels: 256),
    IconSlot(filename: "icon_256x256@2x.png", pixels: 512),
    IconSlot(filename: "icon_512x512.png", pixels: 512),
    IconSlot(filename: "icon_512x512@2x.png", pixels: 1024)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawIcon(size: Int) -> NSBitmapImageRep {
    let dimension = CGFloat(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create bitmap context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let context = NSGraphicsContext.current?.cgContext else { return bitmap }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: dimension, height: dimension))

    let inset = dimension * 0.055
    let iconRect = CGRect(
        x: inset,
        y: inset,
        width: dimension - inset * 2,
        height: dimension - inset * 2
    )
    let cornerRadius = dimension * 0.22
    let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -dimension * 0.025),
        blur: dimension * 0.055,
        color: color(82, 26, 16, 0.42).cgColor
    )
    color(232, 92, 40).setFill()
    iconPath.fill()
    context.restoreGState()

    context.saveGState()
    iconPath.addClip()

    let baseGradient = NSGradient(colors: [
        color(255, 159, 72),
        color(239, 94, 43),
        color(190, 59, 32)
    ])!
    baseGradient.draw(in: iconRect, angle: -45)

    let warmSpot = NSBezierPath(ovalIn: CGRect(
        x: dimension * -0.10,
        y: dimension * 0.56,
        width: dimension * 0.72,
        height: dimension * 0.56
    ))
    color(255, 214, 126, 0.30).setFill()
    warmSpot.fill()

    let lowerShade = NSBezierPath(rect: CGRect(
        x: iconRect.minX,
        y: iconRect.minY,
        width: iconRect.width,
        height: iconRect.height * 0.48
    ))
    color(116, 25, 22, 0.16).setFill()
    lowerShade.fill()

    let glassRect = CGRect(
        x: dimension * 0.18,
        y: dimension * 0.23,
        width: dimension * 0.64,
        height: dimension * 0.54
    )
    let glassRadius = dimension * 0.145
    let glassPath = NSBezierPath(roundedRect: glassRect, xRadius: glassRadius, yRadius: glassRadius)
    color(255, 255, 255, size < 64 ? 0.20 : 0.18).setFill()
    glassPath.fill()
    color(255, 255, 255, size < 64 ? 0.42 : 0.34).setStroke()
    glassPath.lineWidth = max(1, dimension * 0.018)
    glassPath.stroke()

    let shineRect = CGRect(
        x: glassRect.minX + glassRect.width * 0.11,
        y: glassRect.maxY - glassRect.height * 0.28,
        width: glassRect.width * 0.58,
        height: max(1, glassRect.height * 0.045)
    )
    let shinePath = NSBezierPath(roundedRect: shineRect, xRadius: shineRect.height / 2, yRadius: shineRect.height / 2)
    color(255, 255, 255, size < 64 ? 0.50 : 0.36).setFill()
    shinePath.fill()

    let symbol = "%"
    let fontSize = dimension * (size < 64 ? 0.48 : 0.50)
    let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .black)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 0, height: -dimension * 0.018)
    shadow.shadowBlurRadius = dimension * 0.025
    shadow.shadowColor = color(108, 35, 22, 0.36)

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color(255, 255, 255),
        .paragraphStyle: paragraph,
        .shadow: shadow
    ]

    let measured = symbol.size(withAttributes: attributes)
    let textRect = CGRect(
        x: iconRect.minX,
        y: iconRect.midY - measured.height * 0.53,
        width: iconRect.width,
        height: measured.height * 1.08
    )
    symbol.draw(in: textRect, withAttributes: attributes)

    context.restoreGState()

    let rimPath = NSBezierPath(roundedRect: iconRect.insetBy(dx: dimension * 0.014, dy: dimension * 0.014),
                               xRadius: cornerRadius * 0.94,
                               yRadius: cornerRadius * 0.94)
    color(255, 255, 255, 0.20).setStroke()
    rimPath.lineWidth = max(1, dimension * 0.01)
    rimPath.stroke()

    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try png.write(to: url, options: .atomic)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for slot in slots {
    let image = drawIcon(size: slot.pixels)
    let url = outputDirectory.appendingPathComponent(slot.filename)
    try writePNG(image, to: url)
    print("wrote \(slot.filename) (\(slot.pixels)x\(slot.pixels))")
}
