import AppKit
import SwiftUI
import Combine

final class WidgetWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class DesktopController: NSObject, NSWindowDelegate {
    let store: WidgetStore
    var windows: [UUID: WidgetWindow] = [:]
    private var synchronizing = false
    init(store: WidgetStore) {
        self.store = store
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    @objc private func screensChanged() {
        for window in windows.values { fitOnScreen(window) }
    }
    func sync() {
        synchronizing = true
        defer { synchronizing = false }
        let desired = Set(store.widgets.filter(\.visible).map(\.id))
        for id in Array(windows.keys) where !desired.contains(id) {
            windows[id]?.delegate = nil; windows[id]?.close(); windows.removeValue(forKey: id)
        }
        for (index, widget) in store.widgets.enumerated() where widget.visible {
            let window: WidgetWindow
            if let existing = windows[widget.id] { window = existing }
            else {
                let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                let width = 320.0, height = 260.0
                let frame: NSRect
                if let p = widget.placement, [p.x, p.y, p.width, p.height].allSatisfy(\.isFinite), p.width >= 250, p.height >= 180 {
                    frame = NSRect(x: p.x, y: p.y, width: p.width, height: p.height)
                } else {
                    let col = index % max(1, Int((screen.width - 36) / (width + 20)))
                    let row = index / max(1, Int((screen.width - 36) / (width + 20)))
                    frame = NSRect(x: screen.minX + 28 + Double(col) * (width + 20), y: screen.maxY - height - 24 - Double(row % 2) * (height + 20), width: width, height: height)
                }
                window = WidgetWindow(contentRect: frame, styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
                window.identifier = NSUserInterfaceItemIdentifier(widget.id.uuidString)
                window.title = widget.title
                window.isReleasedWhenClosed = false
                window.backgroundColor = .clear; window.isOpaque = false; window.hasShadow = true
                window.contentMinSize = NSSize(width: 270, height: 210)
                window.contentMaxSize = NSSize(width: 900, height: 850)
                window.hidesOnDeactivate = false
                window.becomesKeyOnlyIfNeeded = false
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
                let host = NSHostingView(rootView: WidgetCard(store: store, id: widget.id, desktop: true).preferredColorScheme(.light))
                host.sizingOptions = []
                window.contentView = host
                window.delegate = self
                windows[widget.id] = window
                fitOnScreen(window)
            }
            window.title = widget.title
            window.isMovableByWindowBackground = !widget.locked
            if widget.locked { window.styleMask.remove(.resizable) } else { window.styleMask.insert(.resizable) }
            // Above Finder desktop icons, below ordinary application windows.
            window.level = widget.floating ? .floating : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            window.orderFrontRegardless()
        }
    }
    private func fitOnScreen(_ window: NSWindow) {
        let frame = window.frame
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        var adjusted = frame
        adjusted.size.width = min(frame.width, area.width)
        adjusted.size.height = min(frame.height, area.height)
        adjusted.origin.x = min(max(frame.minX, area.minX), area.maxX - adjusted.width)
        adjusted.origin.y = min(max(frame.minY, area.minY), area.maxY - adjusted.height)
        window.setFrame(adjusted, display: true)
    }
    func windowDidMove(_ notification: Notification) { record(notification) }
    func windowDidResize(_ notification: Notification) { record(notification) }
    private func record(_ notification: Notification) {
        guard !synchronizing, let window = notification.object as? NSWindow,
              let text = window.identifier?.rawValue, let id = UUID(uuidString: text) else { return }
        let f = window.frame
        store.update(id) { $0.placement = WindowPlacement(x: f.minX, y: f.minY, width: f.width, height: f.height) }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: WidgetStore!
    var desktop: DesktopController!
    var mainWindow: NSWindow!
    var statusItem: NSStatusItem!
    var testMode = false
    private var errorSubscription: AnyCancellable?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        testMode = args.contains("--smoke-test")
        let dataURL: URL? = testMode ? URL(fileURLWithPath: "/private/tmp/DeskIsle-Smoke/workspace.json") : nil
        store = WidgetStore(dataURL: dataURL)
        desktop = DesktopController(store: store)
        store.onChange = { [weak self] in self?.desktop.sync() }
        createMenu()
        createMainWindow()
        desktop.sync()
        showManager()
        errorSubscription = store.$errorMessage.compactMap { $0 }.receive(on: RunLoop.main).sink { [weak self] _ in self?.showManager() }
        if testMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.runSmokeChecks()
                self?.writeSmokeDiagnostics()
            }
        }
    }
    private func writeSmokeDiagnostics() {
        let rows: [[String: Any]] = NSApp.windows.map { window in
            ["title": window.title, "window_id": window.windowNumber, "visible": window.isVisible,
             "x": window.frame.minX, "y": window.frame.minY, "width": window.frame.width, "height": window.frame.height,
             "level": window.level.rawValue]
        }
        let value: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier, "windows": rows, "widgets": store.widgets.count]
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: "/private/tmp/DeskIsle-Smoke/diagnostics.json"), options: .atomic)
        }
    }
    private func createMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于桌屿", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "打开组件管理", action: #selector(showManager), keyEquivalent: "0")
        appMenu.addItem(withTitle: "隐藏桌屿", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出桌屿", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; menu.addItem(appItem)
        let editMenu = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        let edit = NSMenuItem(title: "编辑", action: nil, keyEquivalent: ""); edit.submenu = editMenu; menu.addItem(edit)
        NSApp.mainMenu = menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "桌屿组件管理")
        let status = NSMenu()
        status.addItem(withTitle: "桌屿 · DeskIsle", action: nil, keyEquivalent: "")
        status.addItem(.separator())
        status.addItem(withTitle: "打开组件管理", action: #selector(showManager), keyEquivalent: "")
        status.addItem(withTitle: "显示全部组件", action: #selector(showAll), keyEquivalent: "")
        status.addItem(withTitle: "隐藏全部组件", action: #selector(hideAll), keyEquivalent: "")
        status.addItem(withTitle: "导出数据备份…", action: #selector(exportData), keyEquivalent: "")
        status.addItem(.separator())
        status.addItem(withTitle: "退出桌屿", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in appMenu.items where item.action == #selector(showManager) || item.action == #selector(about) { item.target = self }
        for item in status.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem.menu = status
    }
    private func createMainWindow() {
        mainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1160, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        mainWindow.title = "桌屿 · DeskIsle"
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.backgroundColor = NSColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1)
        mainWindow.isReleasedWhenClosed = false
        mainWindow.contentMinSize = NSSize(width: 960, height: 700)
        mainWindow.setFrameAutosaveName(testMode ? "SmokeManager" : "DeskIsleManager")
        mainWindow.center()
        mainWindow.contentView = NSHostingView(rootView: MainView(store: store, revealDesktop: { [weak self] in self?.revealDesktop() }))
    }
    @objc func showManager() { mainWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func showAll() { store.setAllVisible(true) }
    @objc func hideAll() { store.setAllVisible(false) }
    @objc func exportData() { store.exportData() }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "桌屿 DeskIsle", .applicationVersion: "0.1.0", .credits: NSAttributedString(string: "把重要的事，留在桌面。\n独立开发的原生 macOS 桌面组件应用。")]) }
    func revealDesktop() {
        store.setAllVisible(true)
        mainWindow.orderOut(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showManager(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { store.flush() }
}
