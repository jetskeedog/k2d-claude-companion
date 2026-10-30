import AppKit
import SwiftUI

struct ExplorerPane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            ExplorerTabStrip()
            Divider()
            ExplorerTree(tab: state.selectedTab)
                .id(state.selectedTab.id)
        }
    }
}

private struct ExplorerTabStrip: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(state.explorerTabs) { tab in
                        TabButton(tab: tab, isSelected: tab.id == state.selectedTabID)
                    }
                }
                .padding(.horizontal, 6)
            }
            Button { state.chooseFolderForNewTab() } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .help("Open folder in new tab (⌘O)")
            Button { state.showHidden.toggle() } label: {
                Image(systemName: state.showHidden ? "eye" : "eye.slash")
            }
            .buttonStyle(.borderless)
            .help(state.showHidden ? "Hide hidden files (⇧⌘.)" : "Show hidden files (⇧⌘.)")
            .padding(.trailing, 8)
        }
        .frame(height: 30)
        .background(.bar)
    }
}

private struct TabButton: View {
    @Environment(AppState.self) private var state
    let tab: ExplorerTab
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tab.isTerminalLinked ? "terminal" : "folder")
                .font(.system(size: 11))
                .foregroundStyle(tab.isTerminalLinked ? Color.accentColor : .secondary)
            Text(tab.isTerminalLinked ? tab.root.name : tab.title)
                .lineLimit(1)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            if !tab.isTerminalLinked {
                Button { state.closeTab(tab.id) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.borderless)
                .opacity(isHovering || isSelected ? 1 : 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : (isHovering ? Color.primary.opacity(0.06) : .clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { state.selectedTabID = tab.id }
        .onHover { isHovering = $0 }
        .help(tab.root.url.path)
    }
}

private struct ExplorerTree: View {
    @Environment(AppState.self) private var state
    @Bindable var tab: ExplorerTab

    var body: some View {
        VStack(spacing: 0) {
            pathHeader
            Divider()
            List(selection: $tab.selection) {
                ForEach(tab.root.children ?? []) { node in
                    FileNodeRow(node: node)
                }
            }
            .listStyle(.sidebar)
            .contextMenu(forSelectionType: URL.self) { urls in
                if let url = urls.first { menu(for: url) }
            } primaryAction: { urls in
                guard let url = urls.first else { return }
                if isDirectory(url) { state.openTab(url) } else { state.openFile = url }
            }
            .onChange(of: tab.selection) { _, url in
                if let url, !isDirectory(url) { state.openFile = url }
            }
        }
    }

    private var pathHeader: some View {
        HStack(spacing: 6) {
            Button { goUp() } label: { Image(systemName: "arrow.up") }
                .buttonStyle(.borderless)
                .disabled(tab.root.url.path == "/")
                .help(tab.isTerminalLinked ? "cd .. in terminal" : "Go to parent folder")
            Text(abbreviated(tab.root.url))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
                .textSelection(.enabled)
            Spacer()
            if !tab.isTerminalLinked {
                Button { state.cdTerminal(to: tab.root.url) } label: { Image(systemName: "terminal") }
                    .buttonStyle(.borderless)
                    .help("cd here in terminal")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
    }

    @ViewBuilder
    private func menu(for url: URL) -> some View {
        if isDirectory(url) {
            Button("Open in New Tab") { state.openTab(url) }
            Button("cd here in Terminal") { state.cdTerminal(to: url) }
        } else {
            Button("Open in Viewer") { state.openFile = url }
            Button("Open with Default App") { NSWorkspace.shared.open(url) }
        }
        Divider()
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }
    }

    private func goUp() {
        let parent = tab.root.url.deletingLastPathComponent()
        if tab.isTerminalLinked {
            state.cdTerminal(to: parent)
        } else {
            tab.setRoot(parent, showHidden: state.showHidden)
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
    }

    private func abbreviated(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

private struct FileNodeRow: View {
    @Bindable var node: FileNode

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: $node.isExpanded) {
                ForEach(node.children ?? []) { child in
                    FileNodeRow(node: child)
                }
            } label: {
                label
            }
        } else {
            label
        }
    }

    private var label: some View {
        Label {
            Text(node.name).lineLimit(1)
        } icon: {
            Image(nsImage: NSWorkspace.shared.icon(forFile: node.url.path))
                .resizable()
                .frame(width: 16, height: 16)
        }
        .tag(node.url)
    }
}
