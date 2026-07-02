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
        minValue = 0
        maxValue = 1
        isContinuous = true
        sliderType = .linear
        controlSize = .small
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
