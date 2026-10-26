import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum Style {
    static let ink = Color(red: 0.16, green: 0.23, blue: 0.20)
    static let muted = Color(red: 0.48, green: 0.52, blue: 0.48)
    static let green = Color(red: 0.26, green: 0.39, blue: 0.31)
    static let canvas = Color(red: 0.96, green: 0.96, blue: 0.94)
}
extension WidgetTint {
    var background: Color {
        switch self {
        case .sage: return Color(red: 0.91, green: 0.94, blue: 0.88)
        case .sand: return Color(red: 0.97, green: 0.93, blue: 0.83)
        case .rose: return Color(red: 0.98, green: 0.91, blue: 0.87)
        case .sky: return Color(red: 0.88, green: 0.93, blue: 0.97)
        }
    }
    var accent: Color {
        switch self {
        case .sage: return Style.green
        case .sand: return Color(red: 0.57, green: 0.43, blue: 0.21)
        case .rose: return Color(red: 0.64, green: 0.38, blue: 0.30)
        case .sky: return Color(red: 0.29, green: 0.43, blue: 0.59)
        }
    }
}

struct WidgetCard: View {
    @ObservedObject var store: WidgetStore
    let id: UUID
    var desktop = false
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var dropTargeted = false

    var body: some View {
        if let widget = store.widget(id) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: widget.kind.symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(widget.tint.accent)
                    Text(widget.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    if widget.locked { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(Style.muted) }
                    Menu {
                        Button("编辑组件…") { editing = true }
                        if widget.kind == .files || widget.kind == .apps { Button("添加内容…") { store.chooseItems(for: id) } }
                        Button(widget.floating ? "放回桌面层" : "置于所有窗口上方") { store.update(id, { $0.floating.toggle() }, syncWindows: true) }
                        Button(widget.locked ? "解锁位置" : "锁定位置") { store.update(id, { $0.locked.toggle() }, syncWindows: true) }
                        Button(widget.visible ? "从桌面隐藏" : "显示到桌面") { store.update(id, { $0.visible.toggle() }, syncWindows: true) }
                        Divider()
                        Button("删除组件…", role: .destructive) { confirmDelete = true }
                    } label: { Image(systemName: "ellipsis").font(.system(size: 16, weight: .medium)).frame(width: 24, height: 24) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("组件选项")
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                Rectangle().fill(widget.tint.accent.opacity(0.10)).frame(height: 1)
                content(widget)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if !desktop {
                    HStack {
                        Circle().fill(widget.visible ? Style.green : Style.muted.opacity(0.4)).frame(width: 5, height: 5)
                        Text(widget.visible ? "已放置到桌面" : "已隐藏").font(.system(size: 10)).foregroundStyle(Style.muted)
                        Spacer()
                        Button("编辑", action: { editing = true }).font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(widget.tint.accent)
                    }.padding(.horizontal, 18).padding(.bottom, 12)
                }
            }
            .foregroundStyle(Style.ink)
            .background(widget.tint.background.opacity(desktop ? 0.96 : 0.75))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(dropTargeted ? widget.tint.accent : Color.white.opacity(0.7), lineWidth: dropTargeted ? 2 : 1))
            .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
                guard widget.kind == .files || widget.kind == .apps else { return false }
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url { Task { @MainActor in store.addURLs([url], to: id) } }
                    }
                }
                return true
            }
            .sheet(isPresented: $editing) { WidgetEditor(store: store, id: id) }
            .alert("删除「\(widget.title)」？", isPresented: $confirmDelete) {
                Button("取消", role: .cancel) {}
                Button("删除组件", role: .destructive) { store.remove(id) }
            } message: { Text(widget.kind == .notes ? "这会删除该组件的随记内容。" : "只删除桌面组件，原文件和应用会保留。") }
        }
    }

    @ViewBuilder private func content(_ w: DesktopWidget) -> some View {
        switch w.kind {
        case .files, .apps:
            if w.items.isEmpty {
                Button { store.chooseItems(for: id) } label: {
                    VStack(spacing: 9) {
                        Image(systemName: w.kind == .files ? "folder.badge.plus" : "plus.app").font(.system(size: 30, weight: .light))
                        Text(w.kind == .files ? "把文件拖到这里" : "添加常用应用").font(.system(size: 13, weight: .medium))
                        Text(w.kind == .files ? "或点此选择文件与文件夹" : "也可以从 Finder 拖入应用").font(.system(size: 10)).foregroundStyle(Style.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(w.tint.accent.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                }.buttonStyle(.plain).foregroundStyle(w.tint.accent).padding(18)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], spacing: 14) {
                        ForEach(w.items) { item in
                            Button { store.open(item) } label: {
                                VStack(spacing: 6) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().frame(width: 38, height: 38)
                                    Text(item.name).font(.system(size: 10)).lineLimit(2).multilineTextAlignment(.center).frame(height: 27, alignment: .top)
                                }.frame(maxWidth: .infinity).contentShape(Rectangle())
                            }.buttonStyle(.plain).help(item.url.path)
                            .contextMenu {
                                Button("打开") { store.open(item) }
                                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                                Button("从分区移除", role: .destructive) { store.update(id) { $0.items.removeAll { $0.id == item.id } } }
                            }
                        }
                        Button { store.chooseItems(for: id) } label: {
                            Image(systemName: "plus").font(.system(size: 20, weight: .light)).frame(width: 42, height: 55).foregroundStyle(w.tint.accent.opacity(0.6))
                        }.buttonStyle(.plain).help("添加内容")
                    }.padding(18)
                }
            }
        case .countdown:
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let days = w.daysRemaining(now: context.date)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(days < 0 ? "已经一起走过" : days == 0 ? "就是今天" : "距离这一天，还有").font(.system(size: 11)).foregroundStyle(w.tint.accent.opacity(0.8))
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text(String(abs(days))).font(.system(size: desktop ? 64 : 60, weight: .light, design: .rounded)).monospacedDigit()
                            Text("天").font(.system(size: 13))
                        }.foregroundStyle(w.tint.accent)
                        Text(w.targetDate.formatted(.dateTime.year().month().day().weekday(.wide))).font(.system(size: 10)).foregroundStyle(Style.muted)
                    }
                    Spacer(minLength: 10)
                    Image(systemName: "sun.max").font(.system(size: 46, weight: .ultraLight)).foregroundStyle(w.tint.accent.opacity(0.45))
                }.padding(.horizontal, 24).frame(maxHeight: .infinity)
            }
        case .notes:
            if desktop {
                TextEditor(text: Binding(get: { store.widget(id)?.note ?? "" }, set: { text in store.update(id) { $0.note = text } }))
                    .font(.system(size: 13)).lineSpacing(5).scrollContentBackground(.hidden).padding(12)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(w.note.isEmpty ? "点开编辑，记下此刻的想法…" : w.note)
                        .font(.system(size: 12)).lineSpacing(5).foregroundStyle(Style.ink.opacity(0.85)).lineLimit(6)
                    Spacer(minLength: 0)
                }.padding(18)
            }
        }
    }
}

struct WidgetEditor: View {
    @ObservedObject var store: WidgetStore
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    private func binding<T>(_ key: WritableKeyPath<DesktopWidget, T>, fallback: T) -> Binding<T> {
        Binding(get: { store.widget(id)?[keyPath: key] ?? fallback }, set: { value in store.update(id, { $0[keyPath: key] = value }, syncWindows: true) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("编辑组件").font(.system(size: 22, weight: .semibold))
                Spacer()
                Button("完成") { store.flush(); dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(Style.green)
            }
            if let widget = store.widget(id) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("组件名称").font(.system(size: 12, weight: .medium)).foregroundStyle(Style.muted)
                    TextField("名称", text: binding(\.title, fallback: "")).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("色彩").font(.system(size: 12, weight: .medium)).foregroundStyle(Style.muted)
                    HStack(spacing: 12) {
                        ForEach(WidgetTint.allCases) { tint in
                            Button { store.update(id) { $0.tint = tint } } label: {
                                HStack(spacing: 5) {
                                    Circle().fill(tint.background).frame(width: 18, height: 18)
                                    Text(tint.title).font(.system(size: 12))
                                }.padding(8).background(RoundedRectangle(cornerRadius: 8).stroke(widget.tint == tint ? Style.green : Color.gray.opacity(0.2)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if widget.kind == .countdown {
                    DatePicker("目标日期", selection: binding(\.targetDate, fallback: Date()), displayedComponents: .date)
                }
                if widget.kind == .notes {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("随记 · 自动保存").font(.system(size: 12)).foregroundStyle(Style.muted)
                        TextEditor(text: binding(\.note, fallback: "")).font(.system(size: 13)).frame(height: 190).padding(6).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                if widget.kind == .files || widget.kind == .apps {
                    Button { store.chooseItems(for: id) } label: { Label(widget.kind == .files ? "添加文件或文件夹" : "添加应用", systemImage: "plus") }
                }
                Divider()
                Toggle("显示在桌面", isOn: binding(\.visible, fallback: true))
                Toggle("始终置顶", isOn: binding(\.floating, fallback: false))
                Toggle("锁定位置与尺寸", isOn: binding(\.locked, fallback: false))
                Text("拖动组件顶部移动位置，拖动窗口边缘调整大小。\n取消置顶后，组件会留在普通应用窗口的下方。").font(.system(size: 11)).foregroundStyle(Style.muted).lineSpacing(4)
            }
        }.padding(28).frame(width: 460).foregroundStyle(Style.ink).background(Style.canvas)
    }
}
