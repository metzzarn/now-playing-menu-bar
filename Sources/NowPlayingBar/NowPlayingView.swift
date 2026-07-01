import AppKit
import NowPlayingCore

@MainActor
protocol NowPlayingViewDelegate: AnyObject {
    func didTapPrevious()
    func didTapPlayPause()
    func didTapNext()
}

final class NowPlayingView: NSView {
    weak var delegate: NowPlayingViewDelegate?

    private let artworkView = NSImageView()
    private let trackLabel = NowPlayingView.makeLabel(bold: true)
    private let artistLabel = NowPlayingView.makeLabel(bold: false)
    private let albumLabel = NowPlayingView.makeLabel(bold: false)
    private let progressBar = NSProgressIndicator()
    private let positionLabel = NowPlayingView.makeTimeLabel()
    private let lengthLabel = NowPlayingView.makeTimeLabel()
    private let previousButton = NSButton()
    private let playPauseButton = NSButton()
    private let nextButton = NSButton()

    private static let placeholder = NSImage(
        systemSymbolName: "music.note", accessibilityDescription: nil) ?? NSImage()

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 340, height: 150))
        setup()
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    // MARK: - Public API

    func update(state: PlaybackState, artwork: NSImage?) {
        trackLabel.stringValue = state.track
        artistLabel.stringValue = state.artist
        albumLabel.stringValue = state.album
        artworkView.image = artwork ?? Self.placeholder
        progressBar.maxValue = Double(max(state.durationMs, 1))
        progressBar.doubleValue = Double(min(state.progressMs, state.durationMs))
        positionLabel.stringValue = TimeFormatter.string(fromMs: state.progressMs)
        lengthLabel.stringValue = TimeFormatter.string(fromMs: state.durationMs)
        playPauseButton.image = NSImage(
            systemSymbolName: state.isPlaying ? "pause.fill" : "play.fill",
            accessibilityDescription: nil)
        [previousButton, playPauseButton, nextButton].forEach { $0.isEnabled = true }
    }

    func updateProgress(ms: Int) {
        progressBar.doubleValue = Double(min(ms, Int(progressBar.maxValue)))
        positionLabel.stringValue = TimeFormatter.string(fromMs: ms)
    }

    func showNothingPlaying() {
        trackLabel.stringValue = "Nothing playing"
        artistLabel.stringValue = ""
        albumLabel.stringValue = ""
        artworkView.image = Self.placeholder
        progressBar.doubleValue = 0
        positionLabel.stringValue = "0:00"
        lengthLabel.stringValue = "0:00"
        [previousButton, playPauseButton, nextButton].forEach { $0.isEnabled = false }
    }

    // MARK: - Setup

    private func setup() {
        artworkView.imageScaling = .scaleProportionallyUpOrDown
        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 6
        artworkView.layer?.masksToBounds = true
        artworkView.image = Self.placeholder
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        artworkView.heightAnchor.constraint(equalToConstant: 64).isActive = true

        artworkView.setContentHuggingPriority(.required, for: .horizontal)

        let labels = NSStackView(views: [trackLabel, artistLabel, albumLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        let spacer = NSView()
        let times = NSStackView(views: [positionLabel, spacer, lengthLabel])
        times.orientation = .horizontal
        times.distribution = .fill
        positionLabel.setContentHuggingPriority(.required, for: .horizontal)
        lengthLabel.setContentHuggingPriority(.required, for: .horizontal)

        configureButton(previousButton, symbol: "backward.fill", action: #selector(previousTapped))
        configureButton(playPauseButton, symbol: "play.fill", action: #selector(playPauseTapped))
        configureButton(nextButton, symbol: "forward.fill", action: #selector(nextTapped))

        let buttons = NSStackView(views: [previousButton, playPauseButton, nextButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 28

        let rightColumn = NSStackView(views: [labels, progressBar, times, buttons])
        rightColumn.orientation = .vertical
        rightColumn.alignment = .leading
        rightColumn.spacing = 8

        let root = NSStackView(views: [artworkView, rightColumn])
        root.orientation = .horizontal
        root.alignment = .centerY
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            labels.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor),
            labels.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor),
            progressBar.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor),
            times.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor),
            times.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor),
            buttons.centerXAnchor.constraint(equalTo: rightColumn.centerXAnchor),
        ])
    }

    private func configureButton(_ button: NSButton, symbol: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryChange)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private static func makeLabel(bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.font = bold ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 11)
        label.textColor = bold ? .labelColor : .secondaryLabelColor
        return label
    }

    private static func makeTimeLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "0:00")
        label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        label.textColor = .secondaryLabelColor
        return label
    }

    @objc private func previousTapped() { delegate?.didTapPrevious() }
    @objc private func playPauseTapped() { delegate?.didTapPlayPause() }
    @objc private func nextTapped() { delegate?.didTapNext() }
}
