import Foundation

enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case files, apps, countdown, notes
    var id: String { rawValue }
    var title: String {
        switch self { case .files: return "文件分区"; case .apps: return "应用分区"; case .countdown: return "倒数日"; case .notes: return "项目随记" }
    }
    var symbol: String {
        switch self { case .files: return "folder"; case .apps: return "square.grid.2x2"; case .countdown: return "calendar"; case .notes: return "text.alignleft" }
    }
    var subtitle: String {
        switch self { case .files: return "常用文件，触手可及"; case .apps: return "把工作入口放在桌面"; case .countdown: return "让每个重要日子有迹可循"; case .notes: return "留住灵感，专注当下" }
    }
}

enum WidgetTint: String, Codable, CaseIterable, Identifiable {
    case sage, sand, rose, sky
    var id: String { rawValue }
    var title: String { switch self { case .sage: return "苔绿"; case .sand: return "暖沙"; case .rose: return "浅桃"; case .sky: return "雾蓝" } }
}

struct LinkedItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var path: String
    var bookmark: Data?
    init(url: URL) {
        name = url.deletingPathExtension().lastPathComponent
        if url.pathExtension != "app" { name = url.lastPathComponent }
        path = url.path
        bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }
    var url: URL {
        if let bookmark {
            var stale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) { return resolved }
        }
        return URL(fileURLWithPath: path)
    }
}

struct WindowPlacement: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct DesktopWidget: Codable, Identifiable {
    var id = UUID()
    var kind: WidgetKind
    var title: String
    var tint: WidgetTint = .sage
    var visible = true
    var floating = false
    var locked = false
    var items: [LinkedItem] = []
    var targetDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    var note = ""
    var placement: WindowPlacement?

    func daysRemaining(now: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: targetDate)).day ?? 0
    }
    static func make(_ kind: WidgetKind) -> DesktopWidget {
        DesktopWidget(kind: kind, title: kind.title, tint: kind == .countdown ? .sand : kind == .notes ? .rose : kind == .apps ? .sky : .sage)
    }
    static var starter: [DesktopWidget] {
        var countdown = make(.countdown)
        countdown.title = "下一个里程碑"
        var note = make(.notes)
        note.title = "我的第一个项目"
        note.note = "每一个好想法，都值得被记下来。\n\n今天想完成什么？\n• 写下你的目标\n• 从一件小事开始\n• 为进展留一点记录"
        return [make(.files), make(.apps), countdown, note]
    }
}

struct WorkspaceDocument: Codable {
    var version = 1
    var widgets: [DesktopWidget]
}

enum DocumentError: LocalizedError {
    case unsupportedVersion(Int)
    case duplicateIdentifiers
    var errorDescription: String? {
        switch self { case .unsupportedVersion(let v): return "数据版本 \(v) 高于此版本支持的格式，请保留数据并升级应用。"; case .duplicateIdentifiers: return "组件数据包含重复标识，未载入此文件。" }
    }
}

enum DocumentIO {
    static func load(from url: URL) throws -> [DesktopWidget] {
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(WorkspaceDocument.self, from: data)
        guard document.version == 1 else { throw DocumentError.unsupportedVersion(document.version) }
        guard Set(document.widgets.map(\.id)).count == document.widgets.count else { throw DocumentError.duplicateIdentifiers }
        return document.widgets
    }
    static func save(_ widgets: [DesktopWidget], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(WorkspaceDocument(widgets: widgets))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path), (try? load(from: url)) != nil {
            try Data(contentsOf: url).write(to: url.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }
}
