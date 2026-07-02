import AppKit
import NowPlayingCore

/// Passive status-bar display: draws the title (with optional marquee scroll) and,
/// when enabled, a thin progress bar beneath it. Clicks pass through to the
/// underlying NSStatusBarButton via `hitTest` returning nil.
final class StatusItemView: NSView {
    private var text = "Login"
    private var progress: Double?
    private var style = MenuBarStyle(
        progressBarEnabled: PreferenceDefaults.progressBarEnabled,
        thickness: CGFloat(PreferenceDefaults.progressBarThickness),
        colorHex: PreferenceDefaults.progressBarColorHex,
        scrollEnabled: PreferenceDefaults.scrollEnabled,
        scrollSpeed: CGFloat(PreferenceDefaults.scrollSpeed),
        useStaticWidth: PreferenceDefaults.useStaticWidth,
        staticWidth: CGFloat(PreferenceDefaults.staticWidth),
        maxWidth: CGFloat(PreferenceDefaults.maxWidth),
        pauseAtEnds: PreferenceDefaults.scrollPauseAtEnds,
        alignment: PreferenceDefaults.textAlignment)

    private var textWidth: CGFloat = 0
    private var hasTrack = false
    private var forceWhiteText = false
    private var scrollStart = Date()
    private var marqueeTimer: Timer?

    private let font = NSFont.menuBarFont(ofSize: 0)
    private let horizontalPadding: CGFloat = 6

    /// Static width applies only while a track is showing; otherwise the item
    /// sizes to the (short) idle/login text.
    private var usesStaticWidth: Bool { style.useStaticWidth && hasTrack }

    /// Width the status item should occupy: a fixed static width, or the text
    /// width capped at the max width.
    var desiredWidth: CGFloat {
        let base = usesStaticWidth ? style.staticWidth : min(textWidth, style.maxWidth)
        return base + horizontalPadding
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(text: String, progress: Double?, hasTrack: Bool, forceWhiteText: Bool,
                style: MenuBarStyle) {
        let textChanged = text != self.text
        self.text = text
        self.progress = progress
        self.hasTrack = hasTrack
        self.forceWhiteText = forceWhiteText
        self.style = style
        self.textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        if textChanged { scrollStart = Date() }
        syncMarqueeTimer()
        needsDisplay = true
    }

    // Decided against the active width cap, not the current bounds, so the
    // decision doesn't depend on statusItem.length having been applied yet.
    private var isScrolling: Bool {
        let cap = usesStaticWidth ? style.staticWidth : style.maxWidth
        return style.scrollEnabled && textWidth > cap + 0.5
    }

    private func syncMarqueeTimer() {
        if isScrolling {
            if marqueeTimer == nil {
                scrollStart = Date()
                let timer = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
                    self?.needsDisplay = true
                }
                RunLoop.main.add(timer, forMode: .common)
                marqueeTimer = timer
            }
        } else {
            marqueeTimer?.invalidate()
            marqueeTimer = nil
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSBezierPath(rect: bounds).addClip()

        let titleColor = forceWhiteText
            ? .white
            : (style.textColorHex.flatMap(NSColor.fromHex) ?? .labelColor)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: titleColor,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let barSpace: CGFloat = (style.progressBarEnabled && progress != nil)
            ? style.thickness + 2 : 0
        let textY = barSpace + (bounds.height - barSpace - textSize.height) / 2
        let textAreaWidth = bounds.width - horizontalPadding

        if isScrolling {
            let offset = Marquee.offset(
                elapsed: Date().timeIntervalSince(scrollStart),
                textWidth: textWidth, viewWidth: textAreaWidth,
                speed: style.scrollSpeed, pause: style.pauseAtEnds)
            (text as NSString).draw(
                at: NSPoint(x: horizontalPadding / 2 - offset, y: textY), withAttributes: attrs)
        } else {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            switch style.alignment {
            case .left: paragraph.alignment = .left
            case .center: paragraph.alignment = .center
            case .right: paragraph.alignment = .right
            }
            var truncating = attrs
            truncating[.paragraphStyle] = paragraph
            let rect = NSRect(x: horizontalPadding / 2, y: textY,
                              width: textAreaWidth, height: textSize.height)
            (text as NSString).draw(in: rect, withAttributes: truncating)
        }

        if barSpace > 0, let progress {
            let fraction = CGFloat(max(0, min(1, progress)))
            let backgroundRect = NSRect(x: 0, y: 1, width: bounds.width, height: style.thickness)
            let barBackground = style.barBackgroundColorHex.flatMap(NSColor.fromHex)
                ?? NSColor.labelColor.withAlphaComponent(0.2)
            barBackground.setFill()
            NSBezierPath(rect: backgroundRect).fill()
            let fillRect = NSRect(x: 0, y: 1, width: bounds.width * fraction, height: style.thickness)
            (NSColor.fromHex(style.colorHex) ?? .labelColor).setFill()
            NSBezierPath(rect: fillRect).fill()
        }
    }
}
