import AppKit
import Combine
import SwiftUI

@main
enum Sideglance {
    static func main() {
        let app = NSApplication.shared
        let delegate = SideglanceDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class SideglanceDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let appearance = Appearance()
    private let camera = Camera()
    private var snapshot = Camera.Snapshot()
    private var subscriptions = Set<AnyCancellable>()
    private var window: NSWindow!
    private var preview: Preview!
    private lazy var borderPanel = makeBorderPanel()
    private let cameraMenu = NSMenu(title: "Camera")
    private var pinItem: NSMenuItem!
    private var mirrorItem: NSMenuItem!
    private var preferredID = UserDefaults.standard.string(forKey: "preferredCameraID")

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeWindow()
        makeMenu()

        Publishers.CombineLatest3(appearance.$borderHex, appearance.$borderWidth, appearance.$cornerRadius)
            .sink { [weak self] hex, width, radius in
                self?.preview.applyAppearance(hex: hex, width: width, radius: radius)
            }
            .store(in: &subscriptions)
        appearance.$pinned.sink { [weak self] in self?.applyPin($0) }.store(in: &subscriptions)
        appearance.$mirrored.sink { [weak self] in
            self?.mirrorItem.state = $0 ? .on : .off
            self?.camera.setMirrored($0)
        }.store(in: &subscriptions)
        camera.onChange = { [weak self] snapshot in
            self?.snapshot = snapshot
            self?.preview.setState(snapshot.state)
        }

        camera.select(preferredID)
        showPreview()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() {
        preview = Preview(video: camera.previewLayer) { [weak self] in self?.handleCameraAction() }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 330, height: 388),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = UserDefaults.standard.string(forKey: "previewTitle") ?? "Sideglance"
        window.titlebarSeparatorStyle = .none
        window.contentView = preview
        window.contentMinSize = NSSize(width: 252, height: 198)
        window.isReleasedWhenClosed = false
        window.delegate = self

        if let frame = NSScreen.main?.visibleFrame {
            window.setFrameOrigin(NSPoint(x: frame.maxX - window.frame.width - 28, y: frame.midY - window.frame.height / 2))
        } else {
            window.center()
        }
        window.setFrameUsingName("CameraPreview")
        window.setFrameAutosaveName("CameraPreview")
    }

    private func makeBorderPanel() -> NSPanel {
        let content = NSHostingController(rootView: AppearanceView(appearance: appearance))
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Border Settings"
        panel.contentViewController = content
        panel.setContentSize(content.view.fittingSize)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.tabbingMode = .disallowed
        return panel
    }

    private func makeMenu() {
        let main = NSMenu()

        let app = addMenu("Sideglance", to: main)
        app.addItem(withTitle: "About Sideglance", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Sideglance", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = app.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Sideglance", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // The standard Edit menu supplies the responder-chain shortcuts to the hex field.
        let edit = addMenu("Edit", to: main)
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let view = addMenu("View", to: main)
        pinItem = addAction("Keep on Top", #selector(togglePin), key: "t", to: view)
        addAction("Border Settings…", #selector(showBorderSettings), key: ",", to: view)
        addAction("Rename Preview…", #selector(renamePreview), key: "", to: view)
        mirrorItem = addAction("Mirror Preview", #selector(toggleMirror), key: "", to: view)

        let cameraItem = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
        cameraItem.submenu = cameraMenu
        cameraMenu.delegate = self
        main.addItem(cameraItem)

        let windows = addMenu("Window", to: main)
        addAction("Show Preview", #selector(showPreview), key: "1", to: windows)
        windows.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windows.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.windowsMenu = windows
        NSApp.mainMenu = main
    }

    private func addMenu(_ title: String, to main: NSMenu) -> NSMenu {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        item.submenu = submenu
        main.addItem(item)
        return submenu
    }

    @discardableResult
    private func addAction(_ title: String, _ action: Selector, key: String, to menu: NSMenu) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === cameraMenu else { return }
        menu.removeAllItems()
        let automatic = addAction("System Default", #selector(chooseCamera(_:)), key: "", to: menu)
        automatic.state = preferredID == nil ? .on : .off
        for device in snapshot.devices {
            let item = addAction(device.name, #selector(chooseCamera(_:)), key: "", to: menu)
            item.representedObject = device.id
            item.state = device.id == preferredID ? .on : .off
            if device.id == snapshot.activeID {
                item.title += " (In Use)"
            }
        }
        menu.addItem(.separator())
        addAction("Refresh Preview", #selector(refreshCamera), key: "r", to: menu)
    }

    @objc private func chooseCamera(_ sender: NSMenuItem) {
        preferredID = sender.representedObject as? String
        UserDefaults.standard.set(preferredID, forKey: "preferredCameraID")
        camera.select(preferredID)
    }

    private func applyPin(_ pinned: Bool) {
        window.level = pinned ? .floating : .normal
        window.collectionBehavior = pinned
            ? [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary]
            : [.fullScreenNone]
        pinItem.state = pinned ? .on : .off
        if window.isVisible { window.orderFront(nil) }
        if borderPanel.isVisible { borderPanel.orderFront(nil) }
    }

    @objc private func togglePin() { appearance.pinned.toggle() }
    @objc private func toggleMirror() { appearance.mirrored.toggle() }

    @objc private func showBorderSettings() {
        if !borderPanel.isVisible {
            showPreview()
            if let screen = window.screen ?? NSScreen.main {
                let frame = screen.visibleFrame.insetBy(dx: 10, dy: 10)
                let size = borderPanel.frame.size
                let right = window.frame.maxX + 10
                let left = window.frame.minX - 10 - size.width
                let x = right + size.width <= frame.maxX ? right : max(frame.minX, min(left, frame.maxX - size.width))
                let y = max(frame.minY, min(window.frame.maxY, frame.maxY) - size.height)
                borderPanel.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                borderPanel.center()
            }
        }
        borderPanel.makeKeyAndOrderFront(nil)
    }

    @objc private func renamePreview() {
        guard window.attachedSheet == nil else { return }
        showPreview()
        let field = NSTextField(string: window.title)
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        field.setAccessibilityLabel("Window title")

        let alert = NSAlert()
        alert.messageText = "Rename Preview"
        alert.informativeText = "Leave the name blank to hide the title."
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            let title = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            self.window.title = title
            UserDefaults.standard.set(title, forKey: "previewTitle")
        }
    }

    @objc private func showPreview() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        updateVisibility()
    }

    @objc private func refreshCamera() {
        showPreview()
        camera.retry()
    }

    private func handleCameraAction() {
        switch snapshot.state {
        case .permission:
            camera.requestAccess()
        case .denied:
            if let pane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(pane)
            }
        default:
            camera.retry()
        }
    }

    private func updateVisibility() {
        camera.setPreviewVisible(window.isVisible && !window.isMiniaturized && !NSApp.isHidden)
    }

    func windowWillClose(_ notification: Notification) {
        borderPanel.orderOut(nil)
        camera.setPreviewVisible(false)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        borderPanel.orderOut(nil)
        updateVisibility()
    }
    func windowDidDeminiaturize(_ notification: Notification) { updateVisibility() }
    func applicationDidHide(_ notification: Notification) { updateVisibility() }
    func applicationDidUnhide(_ notification: Notification) { updateVisibility() }
    func applicationDidBecomeActive(_ notification: Notification) {
        if window != nil, snapshot.state == .denied { camera.retry() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreview()
        return false
    }
}
