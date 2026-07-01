import AppKit
import NowPlayingCore

extension NSColor {
    static func fromHex(_ hex: String) -> NSColor? {
        guard let c = ColorComponents.parse(hex: hex) else { return nil }
        return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }

    var hexRGBA: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        let a = Int(round(c.alphaComponent * 255))
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}
