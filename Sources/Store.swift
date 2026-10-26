import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor final class WidgetStore: ObservableObject {
    @Published var widgets: [DesktopWidget] = []
    @Published var errorMessage: String?
    @Published var storageReady = true
    let dataURL: URL
    var onChange: (() -> Void)?
    private var saveWork: DispatchWorkItem?
    private var dirty = false
    private var readOnly = false

    init(dataURL: URL? = nil) {
        self.dataURL = dataURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DeskIsle/workspace.json")
        if FileManager.default.fileExists(atPath: self.dataURL.path) {
            do { widgets = try DocumentIO.load(from: self.dataURL) }
            catch {
                // Never replace an unreadable document with default data.
                readOnly = true
                storageReady = false
                errorMessage = "无法读取本地数据：\(error.localizedDescription)\n原文件已保留：\(self.dataURL.path)"
            }
        } else { widgets = DesktopWidget.starter; dirty = true; flush() }
    }
    func widget(_ id: UUID) -> DesktopWidget? { widgets.first { $0.id == id } }
    func update(_ id: UUID, _ change: (inout DesktopWidget) -> Void, syncWindows: Bool = false) {
        guard !readOnly, let i = widgets.firstIndex(where: { $0.id == id }) else { return }
        change(&widgets[i]); changed(syncWindows: syncWindows)
    }
    func add(_ kind: WidgetKind) {
        guard !readOnly else { return }
        widgets.append(.make(kind)); changed(syncWindows: true)
    }
    func remove(_ id: UUID) {
        guard !readOnly else { return }
        widgets.removeAll { $0.id == id }; changed(syncWindows: true)
    }
    func setAllVisible(_ visible: Bool) {
        guard !readOnly else { return }
        for i in widgets.indices { widgets[i].visible = visible }; changed(syncWindows: true)
    }
    func changed(syncWindows: Bool) {
        dirty = true
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        if syncWindows { onChange?() }
    }
    func flush() {
        saveWork?.cancel()
        guard dirty, !readOnly else { return }
        do { try DocumentIO.save(widgets, to: dataURL); dirty = false }
        catch { errorMessage = "保存失败：\(error.localizedDescription)。请检查磁盘空间与目录权限。" }
    }
    func addURLs(_ urls: [URL], to id: UUID) {
        guard let widget = widget(id), [.files, .apps].contains(widget.kind) else { return }
        let accepted = urls.filter { url in
            url.isFileURL && FileManager.default.fileExists(atPath: url.path) && (widget.kind != .apps || url.pathExtension.lowercased() == "app")
        }
        if accepted.count != urls.count { errorMessage = widget.kind == .apps ? "应用分区只接受 .app 应用。" : "部分文件已不存在，未添加。" }
        update(id) { w in
            for url in accepted where !w.items.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
                w.items.append(LinkedItem(url: url))
            }
        }
    }
    func chooseItems(for id: UUID) {
        guard let widget = widget(id) else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = widget.kind == .files
        panel.allowsMultipleSelection = true
        panel.message = widget.kind == .apps ? "选择要放到桌面的应用" : "添加文件或文件夹的快捷引用，原文件位置保持不变"
        if widget.kind == .apps { panel.allowedContentTypes = [.applicationBundle]; panel.directoryURL = URL(fileURLWithPath: "/Applications") }
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK { addURLs(panel.urls, to: id) }
    }
    func open(_ item: LinkedItem) {
        let url = item.url
        guard FileManager.default.fileExists(atPath: url.path) else { errorMessage = "找不到「\(item.name)」，请重新添加它的位置。"; return }
        NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            if let error { Task { @MainActor in self?.errorMessage = "无法打开：\(error.localizedDescription)" } }
        }
    }
    func exportData() {
        flush()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "桌屿备份.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do { try DocumentIO.save(widgets, to: url) } catch { errorMessage = error.localizedDescription }
        }
    }
}
