import Foundation

public struct ColorComponents: Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses `#RRGGBB` or `#RRGGBBAA` (leading `#` optional, case-insensitive).
    /// Returns nil for any other length or non-hex input.
    public static func parse(hex: String) -> ColorComponents? {
        var string = hex
        if string.hasPrefix("#") { string.removeFirst() }
        let hasAlpha = string.count == 8
        guard string.count == 6 || string.count == 8,
              string.allSatisfy(\.isHexDigit),
              let value = UInt64(string, radix: 16) else {
            return nil
        }
        if hasAlpha {
            return ColorComponents(
                red: Double((value >> 24) & 0xFF) / 255,
                green: Double((value >> 16) & 0xFF) / 255,
                blue: Double((value >> 8) & 0xFF) / 255,
                alpha: Double(value & 0xFF) / 255)
        }
        return ColorComponents(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            alpha: 1)
    }
}
