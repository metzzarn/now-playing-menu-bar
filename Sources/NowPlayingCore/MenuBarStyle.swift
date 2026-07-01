import Foundation
import CoreGraphics

public struct MenuBarStyle: Equatable {
    public let progressBarEnabled: Bool
    public let thickness: CGFloat
    public let colorHex: String
    public let scrollEnabled: Bool
    public let scrollSpeed: CGFloat
    public let minWidth: CGFloat
    public let maxWidth: CGFloat
    public let pauseAtEnds: TimeInterval

    public init(progressBarEnabled: Bool, thickness: CGFloat, colorHex: String,
                scrollEnabled: Bool, scrollSpeed: CGFloat, minWidth: CGFloat,
                maxWidth: CGFloat, pauseAtEnds: TimeInterval) {
        self.progressBarEnabled = progressBarEnabled
        self.thickness = thickness
        self.colorHex = colorHex
        self.scrollEnabled = scrollEnabled
        self.scrollSpeed = scrollSpeed
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.pauseAtEnds = pauseAtEnds
    }
}
