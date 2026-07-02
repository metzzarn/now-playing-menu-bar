import AppKit

/// A slider styled as a seek bar. Built on NSSlider (an NSControl) so its events
/// are delivered reliably inside an open NSMenu, where a plain NSView's
/// mouseDown/Dragged/Up are not. Reports the fraction (0...1) live while dragging
/// and once more when the drag ends.
final class SeekBar: NSSlider {
    var onScrubChanged: ((Double) -> Void)?
    var onScrubEnded: ((Double) -> Void)?

    convenience init() {
        self.init(frame: .zero)
        cell = SeekSliderCell()
        minValue = 0
        maxValue = 1
        isContinuous = true
        target = self
        action = #selector(sliderChanged)
        translatesAutoresizingMaskIntoConstraints = false
    }

    /// Sets the displayed fraction (callers guard against calling this mid-scrub).
    func setFraction(_ value: Double) {
        doubleValue = max(0, min(1, value))
    }

    @objc private func sliderChanged() {
        let fraction = doubleValue
        if NSApp.currentEvent?.type == .leftMouseUp {
            onScrubEnded?(fraction)
        } else {
            onScrubChanged?(fraction)
        }
    }
}

/// Custom-drawn so the filled portion is always the accent color (the stock
/// slider draws it gray until the app is active) and the knob is smaller.
private final class SeekSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let radius = rect.height / 2
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

        let range = maxValue - minValue
        let fraction = range > 0 ? (doubleValue - minValue) / range : 0
        var fill = rect
        fill.size.width = rect.width * CGFloat(max(0, min(1, fraction)))
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius).fill()
    }

    override func drawKnob(_ knobRect: NSRect) {
        let diameter: CGFloat = 11
        let box = NSRect(x: knobRect.midX - diameter / 2, y: knobRect.midY - diameter / 2,
                         width: diameter, height: diameter)
        let path = NSBezierPath(ovalIn: box)
        NSColor.white.setFill()
        path.fill()
        NSColor.black.withAlphaComponent(0.15).setStroke()
        path.stroke()
    }
}
