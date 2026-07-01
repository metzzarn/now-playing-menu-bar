import AppKit

final class MenuBarController {
    func buildMenu(isLoggedIn: Bool,
                   nowPlayingTitle: String,
                   target: AnyObject,
                   authAction: Selector,
                   quitAction: Selector) -> NSMenu {
        let menu = NSMenu()

        let info = NSMenuItem(title: nowPlayingTitle, action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)

        menu.addItem(.separator())

        let auth = NSMenuItem(title: isLoggedIn ? "Logout" : "Login",
                              action: authAction, keyEquivalent: "")
        auth.target = target
        menu.addItem(auth)

        let quit = NSMenuItem(title: "Quit", action: quitAction, keyEquivalent: "q")
        quit.target = target
        menu.addItem(quit)

        return menu
    }
}
