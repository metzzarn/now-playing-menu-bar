import Foundation
import CoreGraphics

public enum Marquee {
    /// Horizontal offset (>= 0) to shift the text left by, for a ping-pong scroll.
    /// Returns 0 when the text fits (`textWidth <= viewWidth`) or `speed <= 0`.
    public static func offset(elapsed: TimeInterval,
                              textWidth: CGFloat,
                              viewWidth: CGFloat,
                              speed: CGFloat,
                              pause: TimeInterval) -> CGFloat {
        guard textWidth > viewWidth, speed > 0 else { return 0 }
        let distance = textWidth - viewWidth
        let legTime = TimeInterval(distance / speed)
        let cycle = 2 * pause + 2 * legTime
        guard cycle > 0 else { return 0 }

        let t = elapsed.truncatingRemainder(dividingBy: cycle)
        if t < pause {
            return 0
        } else if t < pause + legTime {
            return distance * CGFloat((t - pause) / legTime)
        } else if t < 2 * pause + legTime {
            return distance
        } else {
            return distance * CGFloat(1 - (t - (2 * pause + legTime)) / legTime)
        }
    }
}
