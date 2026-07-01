import AppKit
import NowPlayingCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menuBuilder = MenuBarController()
    private let config: SpotifyConfig
    private let auth: SpotifyAuth
    private var client: SpotifyClient!
    private var timer: Timer?
    private var state: DisplayState = .loggedOut

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

        Task { await tick() }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { await self?.tick() }
        }
    }

    private func tick() async {
        guard await auth.isLoggedIn else { applyState(.loggedOut); return }
        do {
            if let np = try await client.currentlyPlaying() {
                applyState(.playing(np))
            } else {
                applyState(.idle)
            }
        } catch SpotifyClientError.unauthorized {
            do {
                _ = try await auth.refresh()
            } catch {
                applyState(.loggedOut)
            }
        } catch {
            // Network hiccup: keep the last shown title, retry next tick.
        }
    }

    private func applyState(_ newState: DisplayState) {
        Task { @MainActor in
            self.state = newState
            let loggedIn = await auth.isLoggedIn
            self.statusItem.button?.title = TitleFormatter.title(for: newState)
            self.statusItem.menu = self.menuBuilder.buildMenu(
                isLoggedIn: loggedIn,
                nowPlayingTitle: TitleFormatter.title(for: newState),
                target: self,
                authAction: #selector(self.toggleAuth),
                quitAction: #selector(self.quit))
        }
    }

    @objc private func toggleAuth() {
        Task {
            if await auth.isLoggedIn {
                await auth.logout()
                applyState(.loggedOut)
            } else {
                await login()
            }
        }
    }

    private func login() async {
        let pkce = PKCE()
        let stateParam = PKCE.makeVerifier(length: 16)
        let url = await auth.authorizeURL(pkce: pkce, state: stateParam)
        let server = LoopbackServer(port: config.port)
        NSWorkspace.shared.open(url)
        do {
            let code = try await server.waitForCode()
            try await auth.exchange(code: code, verifier: pkce.verifier)
            await tick()
        } catch {
            server.stop()
            applyState(.loggedOut)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
