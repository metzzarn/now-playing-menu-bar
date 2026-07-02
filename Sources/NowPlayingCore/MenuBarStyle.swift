import Foundation
import CoreGraphics

public enum MenuBarTextAlignment: String, Equatable, CaseIterable {
    case left, center, right
}

public struct MenuBarStyle: Equatable {
    public let progressBarEnabled: Bool
    public let thickness: CGFloat
    public let colorHex: String
    public let scrollEnabled: Bool
    public let scrollSpeed: CGFloat
    public let useStaticWidth: Bool
    public let staticWidth: CGFloat
    public let maxWidth: CGFloat
    public let pauseAtEnds: TimeInterval
    public let alignment: MenuBarTextAlignment
    /// Menu-bar title color; nil resolves to the system label color.
    public let textColorHex: String?
    /// Progress-bar track (unfilled) color; nil resolves to a translucent label color.
    public let barBackgroundColorHex: String?

    public init(progressBarEnabled: Bool, thickness: CGFloat, colorHex: String,
                scrollEnabled: Bool, scrollSpeed: CGFloat, useStaticWidth: Bool,
                staticWidth: CGFloat, maxWidth: CGFloat, pauseAtEnds: TimeInterval,
                alignment: MenuBarTextAlignment, textColorHex: String? = nil,
                barBackgroundColorHex: String? = nil) {
        self.progressBarEnabled = progressBarEnabled
        self.thickness = thickness
        self.colorHex = colorHex
        self.scrollEnabled = scrollEnabled
        self.scrollSpeed = scrollSpeed
        self.useStaticWidth = useStaticWidth
        self.staticWidth = staticWidth
        self.maxWidth = maxWidth
        self.pauseAtEnds = pauseAtEnds
        self.alignment = alignment
        self.textColorHex = textColorHex
        self.barBackgroundColorHex = barBackgroundColorHex
    }

    /// The width cap the title is laid out against (static width when enabled,
    /// otherwise the max width). Scrolling triggers when the text exceeds this.
    public var widthCap: CGFloat {
        useStaticWidth ? staticWidth : maxWidth
    }
}
