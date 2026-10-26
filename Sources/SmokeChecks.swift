import AppKit

// This integration harness runs only with --smoke-test and uses /private/tmp data.
// It exercises our model/window controllers; it does not synthesize user input.
extension AppDelegate {
    func runSmokeChecks() {
        let baseline = store.widgets
        let directory = URL(fileURLWithPath: "/private/tmp/DeskIsle-Smoke")
        var results: [[String: Any]] = []
        func check(_ name: String, _ condition: Bool) { results.append(["name": name, "passed": condition]) }
        defer {
            store.widgets = baseline
            store.changed(syncWindows: true)
            store.flush()
            let summary: [String: Any] = ["checks": results, "allPassed": results.allSatisfy { $0["passed"] as? Bool == true }]
            if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: directory.appendingPathComponent("runtime-checks.json"), options: .atomic)
            }
        }
        // Render only this application's own view hierarchy, without screen capture.
        if let view = mainWindow.contentView {
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try? data.write(to: directory.appendingPathComponent("native-preview.png"), options: .atomic)
                    check("原生管理视图渲染", bitmap.pixelsWide > 900 && bitmap.pixelsHigh > 600)
                }
            }
        }
        check("初始桌面窗口数量", desktop.windows.count == store.widgets.filter(\.visible).count)
        let before = store.widgets.count
        store.add(.notes)
        guard let created = store.widgets.last else { check("新建组件", false); return }
        let id = created.id
        check("新建组件同步创建窗口", store.widgets.count == before + 1 && desktop.windows[id] != nil)
        store.update(id) { $0.note = "运行验证：中文与换行\n第二行 🏝️"; $0.title = "测试项目" }
        store.flush()
        let restored = try? DocumentIO.load(from: store.dataURL)
        check("编辑与持久化", restored?.last?.note == "运行验证：中文与换行\n第二行 🏝️")
        store.update(id, { $0.floating = true }, syncWindows: true)
        check("置顶窗口层级", desktop.windows[id]?.level == .floating)
        store.update(id, { $0.locked = true }, syncWindows: true)
        check("锁定尺寸与位置", desktop.windows[id]?.styleMask.contains(.resizable) == false && desktop.windows[id]?.isMovableByWindowBackground == false)
        store.update(id, { $0.locked = false }, syncWindows: true)
        if let window = desktop.windows[id] {
            var frame = window.frame
            frame.origin.x += 12; frame.origin.y -= 12; frame.size.width += 20
            window.setFrame(frame, display: true)
            desktop.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: window))
            desktop.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: window))
            store.flush()
            let geometry = try? DocumentIO.load(from: store.dataURL).last?.placement
            check("窗口移动尺寸保存", geometry?.x == frame.minX && geometry?.width == frame.width)
        }
        store.update(id, { $0.visible = false }, syncWindows: true)
        check("隐藏组件关闭窗口", desktop.windows[id] == nil)
        store.update(id, { $0.visible = true }, syncWindows: true)
        check("显示组件恢复窗口位置", desktop.windows[id].map { Double($0.frame.minX) } == store.widget(id)?.placement?.x)
        if let fileWidget = store.widgets.first(where: { $0.kind == .files }) {
            let testFile = directory.appendingPathComponent("reference-test.txt")
            try? "original-content".write(to: testFile, atomically: true, encoding: .utf8)
            store.addURLs([testFile, testFile], to: fileWidget.id)
            check("文件引用去重", store.widget(fileWidget.id)?.items.filter { $0.url.path == testFile.path }.count == 1)
            store.update(fileWidget.id) { $0.items.removeAll { $0.url.path == testFile.path } }
            check("移除引用保留源文件", (try? String(contentsOf: testFile, encoding: .utf8)) == "original-content")
        }
        store.remove(id)
        check("删除组件同步关闭窗口", store.widgets.count == before && desktop.windows[id] == nil)
        store.setAllVisible(false)
        check("隐藏全部组件", desktop.windows.isEmpty)
        store.setAllVisible(true)
        check("显示全部组件", desktop.windows.count == store.widgets.count)
        store.flush()
        check("本地备份存在", FileManager.default.fileExists(atPath: store.dataURL.appendingPathExtension("backup").path))
    }
}
