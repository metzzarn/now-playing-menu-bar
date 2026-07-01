import AppKit

final class MenuBarController {
    /// Right-click / logged-out menu: auth control, Preferences, Quit.
    func simpleMenu(isLoggedIn: Bool,
                    hasClientID: Bool,
                    target: AnyObject,
                    loginAction: Selector,
                    prefsAction: Selector,
                    quitAction: Selector) -> NSMenu {
        let menu = NSMenu()

        if hasClientID {
            let auth = NSMenuItem(title: isLoggedIn ? "Logout" : "Login",
                                  action: loginAction, keyEquivalent: "")
            auth.target = target
            menu.addItem(auth)
        } else {
            let hint = NSMenuItem(title: "Set Client ID in Preferences…",
                                  action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }

        menu.addItem(.separator())
        addTrailingItems(to: menu, target: target, prefsAction: prefsAction, quitAction: quitAction)
        return menu
    }

    /// Left-click / logged-in menu: only the rich now-playing view.
    /// Preferences and Quit are reachable via the right-click menu.
    func richMenu(contentView: NSView) -> NSMenu {
        let menu = NSMenu()
        let item = NSMenuItem()
        item.view = contentView
        menu.addItem(item)
        return menu
    }

    private func addTrailingItems(to menu: NSMenu,
                                  target: AnyObject,
                                  prefsAction: Selector,
                                  quitAction: Selector) {
        let prefs = NSMenuItem(title: "Preferences…", action: prefsAction, keyEquivalent: ",")
        prefs.target = target
        menu.addItem(prefs)

        let quit = NSMenuItem(title: "Quit", action: quitAction, keyEquivalent: "q")
        quit.target = target
        menu.addItem(quit)
    }
}
