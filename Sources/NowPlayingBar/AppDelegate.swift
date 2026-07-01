import AppKit
import NowPlayingCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NowPlayingViewDelegate {
    private var statusItem: NSStatusItem!
    private let menuBuilder = MenuBarController()
    private let nowPlayingView = NowPlayingView()
    private let artworkLoader = ArtworkLoader()

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
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButtonAction()
        startInterpolationTimer()
        updateTitle()

        Task {
            await refreshLoginState()
            updateTitle()
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
            granted: preferences.grantedScope, required: config.scope)
        loggedIn = hasSession && !reauth
    }

    // MARK: - Click routing

    private func configureButtonAction() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        let isRight = NSApp.currentEvent?.type == .rightMouseUp
        let showRich = !isRight && loggedIn && playback != nil

        let menu: NSMenu
        if showRich {
            menu = menuBuilder.richMenu(
                contentView: nowPlayingView, target: self,
                prefsAction: #selector(openPreferences), quitAction: #selector(quit))
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
        nowPlayingView.updateProgress(ms: localProgressMs)
    }

    private func tick() async {
        guard !isTicking, let client, let auth else { return }
        isTicking = true
        defer { isTicking = false }

        await refreshLoginState()
        guard loggedIn else { updateTitle(); return }
        do {
            try await updatePlayback(client)
        } catch SpotifyClientError.unauthorized {
            do {
                _ = try await auth.refresh()
                try await updatePlayback(client)
            } catch {
                loggedIn = false
                playback = nil
                updateTitle()
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
            nowPlayingView.showNothingPlaying()
            updateTitle()
        }
    }

    private func applyPlayback(_ state: PlaybackState) {
        let trackChanged = playback?.artworkURL != state.artworkURL
        playback = state
        localProgressMs = state.progressMs
        if trackChanged { currentArtwork = nil }
        updateTitle()
        nowPlayingView.update(state: state, artwork: currentArtwork)

        if trackChanged, let url = state.artworkURL {
            artworkRequestID += 1
            let requestID = artworkRequestID
            Task {
                let image = await artworkLoader.image(for: url)
                guard requestID == artworkRequestID else { return }
                currentArtwork = image
                if let playback { nowPlayingView.update(state: playback, artwork: image) }
            }
        }
    }

    private func updateTitle() {
        let display: DisplayState
        if !loggedIn {
            display = .loggedOut
        } else if let playback {
            display = .playing(NowPlaying(artist: playback.artist, track: playback.track))
        } else {
            display = .idle
        }
        statusItem.button?.title = TitleFormatter.title(for: display)
    }

    // MARK: - Auth

    @objc private func toggleAuth() {
        Task {
            guard let auth else { return }
            if await auth.isLoggedIn {
                await auth.logout()
                preferences.grantedScope = nil
                loggedIn = false
                playback = nil
                currentArtwork = nil
                stopPolling()
                updateTitle()
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
            preferences.grantedScope = config.scope
            loggedIn = true
            startPolling()
            await tick()
        } catch {
            server.stop()
            applyLoggedOut()
        }
    }

    private func applyLoggedOut() {
        loggedIn = false
        playback = nil
        currentArtwork = nil
        stopPolling()
        updateTitle()
    }

    // MARK: - Preferences

    @objc private func openPreferences() {
        // Recreate each time so the window reflects the current, latest preferences.
        let controller = PreferencesWindowController(preferences: preferences) { [weak self] updated in
            guard let self else { return }
            self.preferences = updated
            self.rebuildClient()
            Task {
                await self.refreshLoginState()
                if self.loggedIn {
                    self.startPolling()
                    await self.tick()
                } else {
                    self.stopPolling()
                }
                self.updateTitle()
            }
        }
        prefsController = controller
        controller.show()
    }

    // MARK: - Transport (NowPlayingViewDelegate)

    func didTapPlayPause() {
        guard let client, let current = playback else { return }
        let optimistic = withPlaying(current, !current.isPlaying)
        playback = optimistic
        nowPlayingView.update(state: optimistic, artwork: currentArtwork)
        Task {
            do {
                if optimistic.isPlaying { try await client.play() } else { try await client.pause() }
            } catch {
                // Only revert if no newer state (e.g. a poll tick) landed meanwhile.
                if playback == optimistic {
                    playback = current
                    nowPlayingView.update(state: current, artwork: currentArtwork)
                }
            }
        }
    }

    func didTapNext() { transport { try await $0.next() } }
    func didTapPrevious() { transport { try await $0.previous() } }

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
        PlaybackState(track: state.track, artist: state.artist, album: state.album,
                      artworkURL: state.artworkURL, isPlaying: isPlaying,
                      progressMs: localProgressMs, durationMs: state.durationMs)
    }

    @objc private func quit() {
        stopPolling()
        interpolationTimer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
}
