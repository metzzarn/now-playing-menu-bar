import AppKit

/// A thin, clickable/draggable progress bar. Reports the scrubbed fraction (0...1)
/// live while dragging and once more when the drag ends.
final class SeekBar: NSView {
    var onScrubChanged: ((Double) -> Void)?
    var onScrubEnded: ((Double) -> Void)?

    private var fraction: Double = 0
    private let trackHeight: CGFloat = 4

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: trackHeight)
    }

    /// Sets the displayed fraction (ignored while the user is scrubbing).
    func setFraction(_ value: Double) {
        fraction = max(0, min(1, value))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let y = (bounds.height - trackHeight) / 2
        let trackRect = NSRect(x: 0, y: y, width: bounds.width, height: trackHeight)
        let radius = trackHeight / 2

        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: radius, yRadius: radius).fill()

        let fillWidth = bounds.width * CGFloat(fraction)
        if fillWidth > 0 {
            let fillRect = NSRect(x: 0, y: y, width: fillWidth, height: trackHeight)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        updateFraction(with: event)
        onScrubChanged?(fraction)
    }

    override func mouseDragged(with event: NSEvent) {
        updateFraction(with: event)
        onScrubChanged?(fraction)
    }

    override func mouseUp(with event: NSEvent) {
        updateFraction(with: event)
        onScrubEnded?(fraction)
    }

    private func updateFraction(with event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        fraction = bounds.width > 0 ? max(0, min(1, Double(x / bounds.width))) : 0
        needsDisplay = true
    }
}
