import AppKit
import NowPlayingCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menuBuilder = MenuBarController()
    private let config: SpotifyConfig
    private let auth: SpotifyAuth
    private var client: SpotifyClient!
    private var timer: Timer?
    private var state: DisplayState = .loggedOut
    private var isTicking = false
    private var isAuthenticating = false

    override init() {
        guard let clientID = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_ID"],
              !clientID.isEmpty else {
            fatalError("Set the SPOTIFY_CLIENT_ID environment variable before launching.")
        }
        self.config = SpotifyConfig(clientID: clientID)
        self.auth = SpotifyAuth(config: config)
        super.init()
        self.client = SpotifyClient(http: URLSession.shared) { [auth] in
            try await auth.validAccessToken()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        applyState(.loggedOut)

        Task {
            if await auth.isLoggedIn {
                startPolling()
                await tick()
            }
        }
    }

    // MARK: - Polling

    private func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { await self?.tick() }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() async {
        guard !isTicking else { return }
        isTicking = true
        defer { isTicking = false }

        guard await auth.isLoggedIn else { applyState(.loggedOut); return }
        do {
            try await updateNowPlaying()
        } catch SpotifyClientError.unauthorized {
            do {
                _ = try await auth.refresh()
                try await updateNowPlaying()
            } catch {
                applyState(.loggedOut)
            }
        } catch {
            // Network hiccup: keep the last shown title, retry next tick.
        }
    }

    private func updateNowPlaying() async throws {
        if let np = try await client.currentlyPlaying() {
            applyState(.playing(np))
        } else {
            applyState(.idle)
        }
    }

    // MARK: - Display

    private func applyState(_ newState: DisplayState) {
        state = newState
        let loggedIn = newState != .loggedOut
        let title = TitleFormatter.title(for: newState)
        statusItem.button?.title = title
        statusItem.menu = menuBuilder.buildMenu(
            isLoggedIn: loggedIn,
            nowPlayingTitle: title,
            target: self,
            authAction: #selector(toggleAuth),
            quitAction: #selector(quit))
    }

    // MARK: - Auth

    @objc private func toggleAuth() {
        Task {
            if await auth.isLoggedIn {
                await auth.logout()
                stopPolling()
                applyState(.loggedOut)
            } else {
                await login()
            }
        }
    }

    private func login() async {
        guard !isAuthenticating else { return }
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
                applyState(.loggedOut)
                return
            }
            try await auth.exchange(code: callback.code, verifier: pkce.verifier)
            startPolling()
            await tick()
        } catch {
            server.stop()
            applyState(.loggedOut)
        }
    }

    @objc private func quit() {
        stopPolling()
        NSApplication.shared.terminate(nil)
    }
}
