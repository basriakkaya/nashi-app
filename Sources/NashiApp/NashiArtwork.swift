import AppKit

/// Kage's vector identity is shared by the interface, menu bar and app icon.
/// The historical source type name is retained to keep the engine integration small.
enum NashiArtwork {
    static let gold = NSColor(srgbRed: 0.94, green: 0.20, blue: 0.29, alpha: 1)
    static let ink = NSColor.white
    static func draw(in rect: NSRect, happy: Bool = false, monochrome: Bool = false) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState(); defer { context.restoreGState() }
        context.translateBy(x: rect.minX, y: rect.maxY); context.scaleBy(x: rect.width, y: -rect.height)
        let color = monochrome ? NSColor.black : gold
        func polygon(_ points: [CGPoint]) {
            let path = CGMutablePath(); path.addLines(between: points); path.closeSubpath(); context.addPath(path); context.fillPath()
        }
        context.setFillColor(color.cgColor)
        polygon([.init(x: 0.18, y: 0.17), .init(x: 0.33, y: 0.17), .init(x: 0.33, y: 0.83), .init(x: 0.18, y: 0.83)])
        polygon([.init(x: 0.34, y: 0.45), .init(x: 0.69, y: 0.17), .init(x: 0.87, y: 0.17), .init(x: 0.48, y: 0.50), .init(x: 0.87, y: 0.83), .init(x: 0.68, y: 0.83), .init(x: 0.34, y: 0.55)])
        context.setFillColor(color.withAlphaComponent(monochrome ? 1 : 0.40).cgColor)
        context.fill(CGRect(x: 0.05, y: 0.91, width: 0.28, height: 0.025))
        context.fill(CGRect(x: 0.69, y: 0.065, width: 0.26, height: 0.025))
    }
    static func mark(size: CGFloat, happy: Bool = false) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in draw(in: rect); return true }
    }
    static func menuIcon(updateAvailable: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            draw(in: rect.insetBy(dx: 1, dy: 1), monochrome: true); return true
        }
        image.isTemplate = true; image.accessibilityDescription = "Kage"; return image
    }
}
