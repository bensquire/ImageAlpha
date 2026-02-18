import AppKit

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Build menu bar early so it's ready before any windows
        NSApp.mainMenu = buildMainMenu()
        updateDitheringMenuState()
        updateSpeedMenuState()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Menu Construction

    private func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "ImageAlpha")
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About ImageAlpha", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide ImageAlpha", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ImageAlpha", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        let recentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "Open Recent")
        recentMenu.addItem(withTitle: "Clear Menu", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
        recentItem.submenu = recentMenu
        fileMenu.addItem(recentItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(withTitle: "Save…", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        let saveAs = fileMenu.addItem(withTitle: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(withTitle: "Revert to Saved", action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")

        // Edit menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(zoomInAction(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(zoomOutAction(_:)), keyEquivalent: "-")

        // Tools menu
        let toolsMenuItem = NSMenuItem()
        mainMenu.addItem(toolsMenuItem)
        let toolsMenu = NSMenu(title: "Tools")
        toolsMenuItem.submenu = toolsMenu
        let ditherSubmenu = NSMenu(title: "Dithering")
        let ditherItem = NSMenuItem(title: "Dithering", action: nil, keyEquivalent: "")
        ditherItem.submenu = ditherSubmenu
        toolsMenu.addItem(ditherItem)

        let auto = ditherSubmenu.addItem(withTitle: "Automatic", action: #selector(setDitheringAutomatic(_:)), keyEquivalent: "")
        auto.tag = -1
        ditherSubmenu.addItem(.separator())
        let on = ditherSubmenu.addItem(withTitle: "Dithered", action: #selector(setDitheringOn(_:)), keyEquivalent: "")
        on.tag = 1
        let off = ditherSubmenu.addItem(withTitle: "No Dithering", action: #selector(setDitheringOff(_:)), keyEquivalent: "")
        off.tag = 0

        // Speed submenu
        let speedSubmenu = NSMenu(title: "Quality")
        let speedItem = NSMenuItem(title: "Quality", action: nil, keyEquivalent: "")
        speedItem.submenu = speedSubmenu
        toolsMenu.addItem(speedItem)

        let speedEntries: [(String, Int)] = [
            ("Best (slowest)", 1),
            ("High", 2),
            ("Default", 3),
            ("Fast", 6),
            ("Fastest (lowest quality)", 10),
        ]
        for (title, speed) in speedEntries {
            let item = speedSubmenu.addItem(withTitle: title, action: #selector(setSpeed(_:)), keyEquivalent: "")
            item.tag = speed
        }

        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        // Help menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        helpMenu.addItem(withTitle: "ImageAlpha Help", action: #selector(NSApplication.showHelp(_:)), keyEquivalent: "?")
        NSApp.helpMenu = helpMenu

        return mainMenu
    }

    // MARK: - View Actions

    @objc func zoomInAction(_ sender: Any?) {
        guard let doc = NSDocumentController.shared.currentDocument as? ImageAlphaDocument,
              let wc = doc.windowControllers.first,
              let hostingView = wc.window?.contentView else { return }
        findCanvasNSView(in: hostingView)?.zoomIn(sender)
    }

    @objc func zoomOutAction(_ sender: Any?) {
        guard let doc = NSDocumentController.shared.currentDocument as? ImageAlphaDocument,
              let wc = doc.windowControllers.first,
              let hostingView = wc.window?.contentView else { return }
        findCanvasNSView(in: hostingView)?.zoomOut(sender)
    }

    private func findCanvasNSView(in view: NSView) -> ImageCanvasNSView? {
        if let canvas = view as? ImageCanvasNSView { return canvas }
        for sub in view.subviews {
            if let found = findCanvasNSView(in: sub) { return found }
        }
        return nil
    }

    // MARK: - Helpers

    private func selectMenuItem(_ sender: NSMenuItem) {
        guard let menu = sender.menu else { return }
        for item in menu.items {
            item.state = item == sender ? .on : .off
        }
    }

    private func selectMenuItem(withTag tag: Int, in menu: NSMenu) {
        for item in menu.items {
            item.state = item.tag == tag ? .on : .off
        }
    }

    private func forEachDocument(_ body: (ImageAlphaDocument) -> Void) {
        for doc in NSDocumentController.shared.documents {
            if let alphaDoc = doc as? ImageAlphaDocument {
                body(alphaDoc)
            }
        }
    }

    // MARK: - Dithering Menu

    @objc func setDitheringAutomatic(_ sender: NSMenuItem) {
        setDitheredPreference(tag: -1, sender: sender)
    }

    @objc func setDitheringOn(_ sender: NSMenuItem) {
        setDitheredPreference(tag: 1, sender: sender)
    }

    @objc func setDitheringOff(_ sender: NSMenuItem) {
        setDitheredPreference(tag: 0, sender: sender)
    }

    private func setDitheredPreference(tag: Int, sender: NSMenuItem) {
        selectMenuItem(sender)

        if tag < 0 {
            UserDefaults.standard.removeObject(forKey: "dithered")
        } else {
            UserDefaults.standard.set(tag != 0, forKey: "dithered")
        }

        forEachDocument { $0.model.updateDithering() }
    }

    private func updateDitheringMenuState() {
        let dithered = UserDefaults.standard.object(forKey: "dithered")
        let tag: Int
        if let val = dithered as? Bool {
            tag = val ? 1 : 0
        } else {
            tag = -1
        }
        if let toolsMenu = NSApp.mainMenu?.item(withTitle: "Tools")?.submenu,
           let ditherItem = toolsMenu.item(withTitle: "Dithering"),
           let ditherMenu = ditherItem.submenu {
            selectMenuItem(withTag: tag, in: ditherMenu)
        }
    }

    // MARK: - Speed Menu

    @objc func setSpeed(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "speed")
        selectMenuItem(sender)
        updateSpeedMenuState()
        forEachDocument { $0.model.updateSpeed() }
    }

    private func updateSpeedMenuState() {
        let savedSpeed = UserDefaults.standard.integer(forKey: "speed")
        let activeSpeed = (savedSpeed >= 1 && savedSpeed <= 10) ? savedSpeed : 3
        if let toolsMenu = NSApp.mainMenu?.item(withTitle: "Tools")?.submenu {
            let speedItem = toolsMenu.items.first(where: { $0.submenu?.title == "Quality" })
            if let speedMenu = speedItem?.submenu {
                var selectedTitle = "Default"
                for item in speedMenu.items {
                    let match = item.tag == activeSpeed
                    item.state = match ? .on : .off
                    if match { selectedTitle = item.title }
                }
                speedItem?.title = "Quality — \(selectedTitle)"
            }
        }
    }

}
