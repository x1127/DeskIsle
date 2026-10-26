import SwiftUI
import AppKit

enum LibraryFilter: Hashable { case all, kind(WidgetKind) }

struct MainView: View {
    @ObservedObject var store: WidgetStore
    var revealDesktop: () -> Void
    @State private var filter: LibraryFilter = .all
    @State private var adding = false
    @State private var search = ""
    @State private var showingHelp = false

    private var filtered: [DesktopWidget] {
        store.widgets.filter { w in
            (filter == .all || filter == .kind(w.kind)) && (search.isEmpty || w.title.localizedCaseInsensitiveContains(search) || w.kind.title.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Color.black.opacity(0.06)).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(filterTitle).font(.system(size: 27, weight: .semibold))
                        Text("让重要的事，在桌面上发生。").font(.system(size: 12)).foregroundStyle(Style.muted)
                    }
                    Spacer()
                    Button { adding = true } label: { Label("添加组件", systemImage: "plus").padding(.horizontal, 9).padding(.vertical, 6) }
                        .buttonStyle(.borderedProminent).tint(Style.green).keyboardShortcut("n", modifiers: .command).disabled(!store.storageReady)
                }.padding(.top, 34).padding(.bottom, 26)
                HStack(spacing: 8) {
                    Image(systemName: "sparkle").font(.system(size: 15))
                    Text("给桌面一点秩序，给想法一点空间。").font(.system(size: 12))
                    Spacer()
                    Button { revealDesktop() } label: { Label("收起管理窗口", systemImage: "arrow.down.right") }.buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                }.foregroundStyle(Style.green).padding(16).background(Color(red: 0.89, green: 0.92, blue: 0.87)).clipShape(RoundedRectangle(cornerRadius: 12))
                HStack {
                    Text("\(filtered.count) 个组件").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "magnifyingglass").foregroundStyle(Style.muted)
                    TextField("搜索组件", text: $search).textFieldStyle(.plain).font(.system(size: 12)).frame(width: 130)
                }.padding(.top, 25).padding(.bottom, 16)
                ScrollView {
                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2").font(.system(size: 38, weight: .ultraLight))
                            Text(search.isEmpty ? "给桌面添一座小岛" : "没有找到相关组件").font(.system(size: 17, weight: .medium))
                            if search.isEmpty { Button("添加你的第一个组件") { adding = true }.buttonStyle(.bordered) }
                        }.foregroundStyle(Style.muted).frame(maxWidth: .infinity).padding(.top, 90)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)], spacing: 20) {
                            ForEach(filtered) { widget in WidgetCard(store: store, id: widget.id).frame(height: 245) }
                        }.padding(.bottom, 24)
                    }
                }.scrollIndicators(.hidden)
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive").font(.system(size: 10))
                    Text("保存在这台 Mac 上").font(.system(size: 10))
                    Spacer()
                    Text("DESKISLE / 桌屿").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2)
                }.foregroundStyle(Style.muted).padding(.vertical, 15)
            }.padding(.horizontal, 32)
        }.background(Style.canvas).foregroundStyle(Style.ink).frame(minWidth: 960, minHeight: 700)
        .sheet(isPresented: $adding) { AddWidgetView(store: store) }
        .sheet(isPresented: $showingHelp) { helpView }
        .alert("需要留意", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("知道了") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .preferredColorScheme(.light)
    }
    private var filterTitle: String {
        if case .kind(let kind) = filter { return kind.title }; return "我的桌面"
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Style.green).frame(width: 39, height: 39)
                    Image(systemName: "square.stack.3d.up.fill").font(.system(size: 20)).foregroundStyle(Color.white.opacity(0.9))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("桌屿").font(.system(size: 23, weight: .semibold))
                    Text("D E S K I S L E").font(.system(size: 8, weight: .medium)).foregroundStyle(Style.muted)
                }
            }.padding(.bottom, 36).padding(.top, 34)
            navRow("全部组件", icon: "square.grid.2x2", selected: filter == .all, count: store.widgets.count) { filter = .all }
            Text("组件分类").font(.system(size: 10, weight: .medium)).foregroundStyle(Style.muted).padding(.top, 29).padding(.bottom, 10).padding(.leading, 12)
            ForEach(WidgetKind.allCases) { kind in
                navRow(kind.title, icon: kind.symbol, selected: filter == .kind(kind), count: store.widgets.filter { $0.kind == kind }.count) { filter = .kind(kind) }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Label("你的桌面，你来定义。", systemImage: "leaf").font(.system(size: 11, weight: .medium))
                Text("四种小组件，\n安放文件、灵感和期待。").font(.system(size: 11)).foregroundStyle(Style.muted).lineSpacing(5)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.bottom, 18)
            HStack(spacing: 14) {
                Button { showingHelp = true } label: { Image(systemName: "questionmark.circle") }.help("使用说明")
                Button { store.exportData() } label: { Image(systemName: "square.and.arrow.up") }.help("导出数据备份")
                Spacer()
                Text("v0.1.0").font(.system(size: 10))
            }.buttonStyle(.plain).foregroundStyle(Style.muted).padding(.horizontal, 12).padding(.bottom, 22)
        }.padding(.horizontal, 18).frame(width: 192).background(Color(red: 0.93, green: 0.94, blue: 0.91))
    }
    private func navRow(_ text: String, icon: String, selected: Bool, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14)).frame(width: 18)
                Text(text).font(.system(size: 12, weight: selected ? .semibold : .regular))
                Spacer()
                Text("\(count)").font(.system(size: 10)).opacity(0.65)
            }.foregroundStyle(selected ? Style.green : Style.ink.opacity(0.7)).padding(.horizontal, 12).padding(.vertical, 13)
                .background(selected ? Color.white.opacity(0.85) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }
    private var helpView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("欢迎来到桌屿").font(.system(size: 24, weight: .semibold))
            Text("01  添加组件\n点右上角「添加组件」，同一类型可以创建多个。\n\n02  整理你的桌面\n文件和应用可从 Finder 拖入，也可以点组件内的添加按钮。点击图标打开，右键移除引用。\n\n03  自由摆放\n拖动桌面组件的顶部移动，拖动边缘改变尺寸。菜单中可以锁定位置、置顶或隐藏。\n\n04  随时记一笔\n直接在桌面项目随记中输入，内容自动保存。菜单栏图标可随时打开管理窗口。").font(.system(size: 13)).lineSpacing(6)
            Text("文件分区使用快捷引用。删除组件或移除引用会保留源文件。数据仅保存在本机，可用左下角导出按钮备份。").font(.system(size: 11)).foregroundStyle(Style.muted)
            Button("打开数据目录") { NSWorkspace.shared.open(store.dataURL.deletingLastPathComponent()) }
            Button("开始使用") { showingHelp = false }.buttonStyle(.borderedProminent).tint(Style.green)
        }.padding(32).frame(width: 490).foregroundStyle(Style.ink).background(Style.canvas)
    }
}

struct AddWidgetView: View {
    @ObservedObject var store: WidgetStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("为桌面添加一座小岛").font(.system(size: 24, weight: .semibold)); Spacer(); Button("取消") { dismiss() } }
            Text("选择一种组件，按你的节奏摆放。").font(.system(size: 12)).foregroundStyle(Style.muted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(WidgetKind.allCases) { kind in
                    let tint = DesktopWidget.make(kind).tint
                    Button { store.add(kind); dismiss() } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: kind.symbol).font(.system(size: 26, weight: .light)).foregroundStyle(tint.accent)
                            Text(kind.title).font(.system(size: 16, weight: .semibold))
                            Text(kind.subtitle).font(.system(size: 11)).foregroundStyle(Style.muted)
                            HStack { Spacer(); Image(systemName: "plus.circle.fill").foregroundStyle(tint.accent) }
                        }.padding(20).frame(maxWidth: .infinity, minHeight: 145, alignment: .leading).background(tint.background).clipShape(RoundedRectangle(cornerRadius: 15))
                    }.buttonStyle(.plain)
                }
            }.padding(.top, 14)
        }.padding(30).frame(width: 590).background(Style.canvas).foregroundStyle(Style.ink)
    }
}
