import AppKit
import NowPlayingCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NowPlayingViewDelegate {
    private var statusItem: NSStatusItem!
    private let menuBuilder = MenuBarController()
    private let nowPlayingView = NowPlayingView()
    private let previewView = NowPlayingView()
    private var previewPanel: NSPanel?
    private let statusView = StatusItemView()
    private let artworkLoader = ArtworkLoader()

    /// The now-playing view in the menu, plus the preview shown while Preferences is open.
    private var nowPlayingViews: [NowPlayingView] { [nowPlayingView, previewView] }

    private var preferences = Preferences()
    private var config: SpotifyConfig?
    private var auth: SpotifyAuth?
    private var client: SpotifyClient?
    private var prefsController: PreferencesWindowController?

    private var playback: PlaybackState?
    private var currentArtwork: NSImage?
    private var artworkRequestID = 0
    private var localProgressMs = 0
    private var loggedIn = false

    private var pollTimer: Timer?
    private var interpolationTimer: Timer?
    private var isTicking = false
    private var isAuthenticating = false

    override init() {
        super.init()
        rebuildClient()
        nowPlayingView.delegate = self
        previewView.delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButtonAction()
        applyAppColors()
        startInterpolationTimer()
        refreshMenuBar()

        Task {
            await refreshLoginState()
            refreshMenuBar()
            if loggedIn {
                startPolling()
                await tick()
            }
        }
    }

    // MARK: - Main menu (enables Cmd+C/V/X/A in text fields for an accessory app)

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let quitItem = appMenu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Client construction

    private func rebuildClient() {
        guard let clientID = ClientIDResolver.resolve(
            preferences: preferences,
            environment: ProcessInfo.processInfo.environment) else {
            config = nil; auth = nil; client = nil
            return
        }
        let config = SpotifyConfig(clientID: clientID)
        self.config = config
        let auth = SpotifyAuth(config: config)
        self.auth = auth
        self.client = SpotifyClient(http: URLSession.shared) { [auth] in
            try await auth.validAccessToken()
        }
    }

    private func refreshLoginState() async {
        guard let auth, let config else { loggedIn = false; return }
        let hasSession = await auth.isLoggedIn
        let reauth = ScopeCheck.needsReauth(
            granted: await auth.grantedScope, required: config.scope)
        loggedIn = hasSession && !reauth
    }

    // MARK: - Click routing

    private func configureButtonAction() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        statusView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(statusView)
        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            statusView.topAnchor.constraint(equalTo: button.topAnchor),
            statusView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        let isRight = NSApp.currentEvent?.type == .rightMouseUp
        let showRich = !isRight && loggedIn && playback != nil

        let menu: NSMenu
        if showRich {
            menu = menuBuilder.richMenu(contentView: nowPlayingView)
        } else {
            menu = menuBuilder.simpleMenu(
                isLoggedIn: loggedIn, hasClientID: config != nil, target: self,
                loginAction: #selector(toggleAuth),
                prefsAction: #selector(openPreferences), quitAction: #selector(quit))
        }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    // MARK: - Polling & interpolation

    private func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: preferences.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func startInterpolationTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.interpolate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        interpolationTimer = timer
    }

    private func interpolate() {
        guard let playback, playback.isPlaying else { return }
        localProgressMs = min(localProgressMs + 1000, playback.durationMs)
        nowPlayingViews.forEach { $0.updateProgress(ms: localProgressMs) }
        refreshMenuBar()
    }

    private func tick() async {
        guard !isTicking, let client, let auth else { return }
        isTicking = true
        defer { isTicking = false }

        await refreshLoginState()
        guard loggedIn else { refreshMenuBar(); return }
        do {
            try await updatePlayback(client)
        } catch SpotifyClientError.unauthorized {
            do {
                _ = try await auth.refresh()
                try await updatePlayback(client)
            } catch {
                loggedIn = false
                playback = nil
                refreshMenuBar()
            }
        } catch {
            // Network hiccup: keep the last shown state, retry next tick.
        }
    }

    private func updatePlayback(_ client: SpotifyClient) async throws {
        if let state = try await client.playbackState() {
            applyPlayback(state)
        } else {
            playback = nil
            currentArtwork = nil
            nowPlayingViews.forEach { $0.showPlaceholder() }
            refreshMenuBar()
        }
    }

    private func applyPlayback(_ state: PlaybackState) {
        let trackChanged = playback?.artworkURL != state.artworkURL
        playback = state
        localProgressMs = state.progressMs
        if trackChanged { currentArtwork = nil }
        refreshMenuBar()
        nowPlayingViews.forEach { $0.update(state: state, artwork: currentArtwork) }

        if trackChanged, let url = state.artworkURL {
            artworkRequestID += 1
            let requestID = artworkRequestID
            Task {
                let image = await artworkLoader.image(for: url)
                guard requestID == artworkRequestID else { return }
                currentArtwork = image
                if let playback {
                    nowPlayingViews.forEach { $0.update(state: playback, artwork: image) }
                }
            }
        }
    }

    private func refreshMenuBar() {
        let text: String
        let progress: Double?
        var hasTrack = false
        var forceWhiteText = false
        if !loggedIn {
            text = "Login"
            progress = nil
        } else if let playback {
            text = TrackTemplate.render(preferences.trackTemplate, values: [
                .title: playback.track,
                .artist: playback.artist,
                .artists: playback.artists.joined(separator: ", "),
                .album: playback.album,
                .year: playback.year ?? "",
            ])
            progress = playback.durationMs > 0
                ? Double(localProgressMs) / Double(playback.durationMs) : nil
            hasTrack = true
        } else {
            text = "♪"  // idle glyph: always white, independent of the text-color setting
            progress = nil
            forceWhiteText = true
        }
        statusView.update(text: text, progress: progress, hasTrack: hasTrack,
                          forceWhiteText: forceWhiteText, style: preferences.menuBarStyle)
        let width = statusView.desiredWidth
        if statusItem.length != width { statusItem.length = width }
    }

    // MARK: - Auth

    @objc private func toggleAuth() {
        Task {
            guard let auth else { return }
            if await auth.isLoggedIn {
                await auth.logout()
                loggedIn = false
                playback = nil
                currentArtwork = nil
                stopPolling()
                refreshMenuBar()
            } else {
                await login()
            }
        }
    }

    private func login() async {
        guard !isAuthenticating, let auth, let config else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let pkce = PKCE()
        let stateParam = PKCE.makeVerifier(length: 16)
        let url = await auth.authorizeURL(pkce: pkce, state: stateParam)
        let server = LoopbackServer(port: config.port)
        NSWorkspace.shared.open(url)
        do {
            let callback = try await server.waitForCode()
            guard callback.state == stateParam else {
                applyLoggedOut()
                return
            }
            try await auth.exchange(code: callback.code, verifier: pkce.verifier)
            guard self.config?.clientID == config.clientID else {
                // Client ID was changed in Preferences mid-login; this flow is stale.
                return
            }
            // Granted scope was persisted to the credentials file by auth.exchange.
            loggedIn = true
            startPolling()
            await tick()
        } catch {
            server.stop()
            applyLoggedOut()
        }
    }

    private func applyAppColors() {
        let background = preferences.appBackgroundColorHex.flatMap(NSColor.fromHex)
            ?? .windowBackgroundColor
        let text = preferences.appTextColorHex.flatMap(NSColor.fromHex) ?? .labelColor
        nowPlayingViews.forEach {
            $0.setColors(background: background, text: text, opacity: preferences.popupOpacity)
        }
    }

    private func applyLoggedOut() {
        loggedIn = false
        playback = nil
        currentArtwork = nil
        stopPolling()
        refreshMenuBar()
    }

    // MARK: - Preferences

    @objc private func openPreferences() {
        // Only one Preferences window at a time: front the existing one if open.
        if let controller = prefsController, controller.window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            controller.window?.makeKeyAndOrderFront(nil)
            showPreview()  // keep the preview visible and repositioned
            return
        }
        // Otherwise create fresh so it reflects the current, latest preferences.
        let controller = PreferencesWindowController(preferences: preferences) { [weak self] updated in
            guard let self else { return }
            self.preferences = updated
            self.rebuildClient()
            self.applyAppColors()
            Task {
                await self.refreshLoginState()
                if self.loggedIn {
                    self.startPolling()
                    await self.tick()
                } else {
                    self.stopPolling()
                }
                self.refreshMenuBar()
            }
        }
        controller.onClose = { [weak self] in self?.hidePreview() }
        prefsController = controller
        controller.show()
        showPreview()
    }

    // MARK: - Now-playing preview (shown while Preferences is open)

    private func showPreview() {
        let panel = previewPanel ?? makePreviewPanel()
        previewPanel = panel
        applyAppColors()
        if loggedIn, let playback {
            previewView.update(state: playback, artwork: currentArtwork)
        } else {
            previewView.showPlaceholder()
        }
        positionPreview(panel)
        panel.orderFront(nil)
    }

    private func hidePreview() {
        previewPanel?.orderOut(nil)
    }

    private func makePreviewPanel() -> NSPanel {
        let size = NSSize(width: 340, height: 150)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        previewView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(previewView)
        // Fixed size so the view can't collapse to its (initially empty) content height.
        NSLayoutConstraint.activate([
            previewView.widthAnchor.constraint(equalToConstant: size.width),
            previewView.heightAnchor.constraint(equalToConstant: size.height),
            previewView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            previewView.topAnchor.constraint(equalTo: content.topAnchor),
            previewView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        panel.contentView = content
        return panel
    }

    private func positionPreview(_ panel: NSPanel) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let inWindow = button.convert(button.bounds, to: nil)
        let onScreen = buttonWindow.convertToScreen(inWindow)
        panel.setFrameOrigin(NSPoint(x: onScreen.minX,
                                     y: onScreen.minY - panel.frame.height - 4))
    }

    // MARK: - Transport (NowPlayingViewDelegate)

    func didTapPlayPause() {
        guard let client, let current = playback else { return }
        let optimistic = withPlaying(current, !current.isPlaying)
        playback = optimistic
        nowPlayingViews.forEach { $0.update(state: optimistic, artwork: currentArtwork) }
        Task {
            do {
                if optimistic.isPlaying { try await client.play() } else { try await client.pause() }
            } catch {
                // Only revert if no newer state (e.g. a poll tick) landed meanwhile.
                if playback == optimistic {
                    playback = current
                    nowPlayingViews.forEach { $0.update(state: current, artwork: currentArtwork) }
                }
            }
        }
    }

    func didTapNext() { transport { try await $0.next() } }
    func didTapPrevious() { transport { try await $0.previous() } }

    func didSeek(toFraction fraction: Double) {
        guard let client, let playback, playback.durationMs > 0 else { return }
        let ms = Int(fraction * Double(playback.durationMs))
        // Assume the released position is correct: keep local progress there and
        // let interpolation continue. No immediate re-poll (Spotify can report
        // stale progress for ~1s after a seek and would snap the bar back).
        localProgressMs = ms
        self.playback = withPlaying(playback, playback.isPlaying)
        nowPlayingViews.forEach { $0.updateProgress(ms: ms) }
        Task {
            try? await client.seek(toMs: ms)
        }
    }

    func didTapArtwork() {
        // Launches Spotify if needed and brings it to the front.
        if let url = URL(string: "spotify:") {
            NSWorkspace.shared.open(url)
        }
    }

    private func transport(_ action: @escaping (SpotifyClient) async throws -> Void) {
        guard let client else { return }
        Task {
            do {
                try await action(client)
                await tick()
            } catch {
                // Control failed (e.g. no active device): next poll reconciles.
            }
        }
    }

    private func withPlaying(_ state: PlaybackState, _ isPlaying: Bool) -> PlaybackState {
        PlaybackState(track: state.track, artist: state.artist, artists: state.artists,
                      album: state.album, year: state.year, artworkURL: state.artworkURL,
                      isPlaying: isPlaying, progressMs: localProgressMs,
                      durationMs: state.durationMs)
    }

    @objc private func quit() {
        stopPolling()
        interpolationTimer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}
