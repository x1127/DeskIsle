import Foundation

@main struct ModelTests {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            guard condition() else { fatalError("FAIL: \(name)") }; checks += 1; print("PASS: \(name)")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        var w = DesktopWidget.make(.countdown)
        w.targetDate = date(2026, 3, 9)
        check(w.daysRemaining(now: date(2026, 3, 8, 23), calendar: calendar) == 1, "DST 跨日仍为一天")
        check(w.daysRemaining(now: date(2026, 3, 9, 18), calendar: calendar) == 0, "目标当天为零")
        check(w.daysRemaining(now: date(2026, 3, 10), calendar: calendar) == -1, "过去日期为负数")
        w.targetDate = date(2028, 3, 1)
        check(w.daysRemaining(now: date(2028, 2, 28), calendar: calendar) == 2, "闰年二月正确")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DeskIsle-Tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("用户文件.txt")
        try "保留原文件".write(to: file, atomically: true, encoding: .utf8)
        var note = DesktopWidget.make(.notes)
        note.note = "中文项目记录 🏝️\n下一步：开始。"
        note.placement = WindowPlacement(x: -100, y: 150, width: 320, height: 260)
        var files = DesktopWidget.make(.files)
        files.items = [LinkedItem(url: file)]
        files.floating = true; files.locked = true; files.visible = false
        let url = dir.appendingPathComponent("workspace.json")
        try DocumentIO.save([note, files, w], to: url)
        let restored = try DocumentIO.load(from: url)
        check(restored.count == 3 && restored[0].id == note.id, "组件与 ID 恢复")
        check(restored[0].note == note.note, "中文、换行和 emoji 保存")
        check(restored[0].placement?.x == -100, "多显示器负坐标保存")
        check(restored[1].locked && restored[1].floating && !restored[1].visible, "显示与锁定偏好保存")
        check(restored[1].items[0].url.standardizedFileURL == file.standardizedFileURL, "文件书签可解析")
        try DocumentIO.save([], to: url)
        let empty = try DocumentIO.load(from: url)
        let backup = try DocumentIO.load(from: url.appendingPathExtension("backup"))
        let original = try String(contentsOf: file, encoding: .utf8)
        check(empty.isEmpty, "主动删除所有组件后保持空状态")
        check(backup.count == 3, "保留上一份有效备份")
        check(original == "保留原文件", "移除组件不修改原文件")
        try Data("坏数据".utf8).write(to: url)
        do { _ = try DocumentIO.load(from: url); fatalError("损坏文件应拒绝") } catch { checks += 1; print("PASS: 拒绝损坏数据") }
        try DocumentIO.save([note, note], to: url)
        do { _ = try DocumentIO.load(from: url); fatalError("重复 ID 应拒绝") } catch { checks += 1; print("PASS: 拒绝重复组件 ID") }
        let future = try JSONEncoder().encode(WorkspaceDocument(version: 2, widgets: []))
        try future.write(to: url)
        do { _ = try DocumentIO.load(from: url); fatalError("未知版本应拒绝") } catch { checks += 1; print("PASS: 拒绝未知数据版本") }
        print("\(checks) checks passed.")
    }
}
