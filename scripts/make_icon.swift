import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outDir = CommandLine.arguments[1]

func whiteSymbolImage(named name: String, pointSize: CGFloat) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return nil }
    base.isTemplate = true
    let size = base.size
    let result = NSImage(size: size)
    result.lockFocus()
    NSColor.white.set()
    NSRect(origin: .zero, size: size).fill()
    base.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1.0)
    result.unlockFocus()
    return result
}

func makeIcon(size: Int) -> NSBitmapImageRep {
    let dim = CGFloat(size)
    let scale: CGFloat = 1
    let pixelDim = Int(dim * scale)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelDim,
        pixelsHigh: pixelDim,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: dim, height: dim)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // Full canvas transparent
    cg.clear(CGRect(x: 0, y: 0, width: dim, height: dim))

    // Backdrop squircle sized per Apple's Big Sur icon grid (~80.5% of canvas)
    let backdrop = dim * 0.8046875
    let inset = (dim - backdrop) / 2
    let radius = backdrop * 0.2247
    let backdropRect = CGRect(x: inset, y: inset, width: backdrop, height: backdrop)

    // Soft drop shadow beneath the backdrop
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -dim * 0.012),
        blur: dim * 0.02,
        color: NSColor.black.withAlphaComponent(0.35).cgColor
    )
    let shadowPath = NSBezierPath(roundedRect: backdropRect, xRadius: radius, yRadius: radius)
    NSColor.black.setFill()
    shadowPath.fill()
    cg.restoreGState()

    // Clip to squircle and paint gradient
    let clipPath = NSBezierPath(roundedRect: backdropRect, xRadius: radius, yRadius: radius)
    cg.saveGState()
    clipPath.addClip()

    let colors = [
        NSColor(calibratedRed: 0.98, green: 0.71, blue: 0.29, alpha: 1.0),
        NSColor(calibratedRed: 0.86, green: 0.42, blue: 0.14, alpha: 1.0)
    ]
    let gradient = NSGradient(colors: colors)!
    gradient.draw(in: backdropRect, angle: -90)

    // Subtle top sheen, fading to nothing by the vertical midpoint so it has no hard seam
    let sheenRect = CGRect(x: backdropRect.minX, y: backdropRect.midY, width: backdropRect.width, height: backdropRect.height / 2)
    let sheenGradient = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.0),
        NSColor.white.withAlphaComponent(0.14)
    ])!
    sheenGradient.draw(in: sheenRect, angle: 90)

    cg.restoreGState()

    // Centered glyph
    if let glyph = whiteSymbolImage(named: "cup.and.saucer.fill", pointSize: backdrop * 0.5) {
        let gSize = glyph.size
        let x = inset + (backdrop - gSize.width) / 2
        let y = inset + (backdrop - gSize.height) / 2 - backdrop * 0.015
        glyph.draw(at: CGPoint(x: x, y: y), from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for size in sizes {
    let rep = makeIcon(size: size)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    let path = "\(outDir)/icon_\(size).png"
    try? data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}
