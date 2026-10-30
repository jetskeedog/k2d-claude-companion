import AppKit
import Observation

enum MarkdownMode: String {
    case raw, read

    mutating func toggle() { self = self == .raw ? .read : .raw }
}

@MainActor
@Observable
final class AppState {
    var terminalCwd: URL {
        didSet {
            guard terminalCwd != oldValue else { return }
            linkedTab.setRoot(terminalCwd, showHidden: showHidden)
        }
    }
    var explorerTabs: [ExplorerTab]
    var selectedTabID: UUID
    var openFile: URL?
    var mdMode: MarkdownMode = .read
    var showHidden = false {
        didSet { explorerTabs.forEach { $0.reload(showHidden: showHidden) } }
    }

    var terminals: [TerminalSession] = []
    var selectedTerminalID: UUID? {
        didSet {
            guard selectedTerminalID != oldValue, let active = terminals.first(where: { $0.id == selectedTerminalID }) else { return }
            terminalCwd = active.currentDirectory
        }
    }

    var favorites: [URL] = Preferences.favorites {
        didSet { Preferences.favorites = favorites }
    }

    init() {
        let start = Preferences.startingDirectory
        let linked = ExplorerTab(rootURL: start, isTerminalLinked: true, showHidden: false)
        terminalCwd = start
        explorerTabs = [linked]
        selectedTabID = linked.id
        newTerminal()
    }

    func chooseFavorite() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add to Favorites"
        panel.directoryURL = terminalCwd
        guard panel.runModal() == .OK else { return }
        for url in panel.urls.map(\.standardizedFileURL) where !favorites.contains(url) {
            favorites.append(url)
        }
    }

    /// Returns true if the favorite was removed.
    @discardableResult
    func requestRemoveFavorite(_ url: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Remove \"\(url.lastPathComponent)\" from Favorites?"
        alert.informativeText = "The folder itself is not deleted.\n\(url.path)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        favorites.removeAll { $0 == url }
        return true
    }

    /// Never empty: closing the last terminal immediately replaces it.
    var activeTerminal: TerminalSession {
        terminals.first { $0.id == selectedTerminalID } ?? terminals[0]
    }

    func openFavorite(_ url: URL) {
        openTab(url)
        newTerminal(in: url)
    }

    func newTerminal(in requested: URL? = nil) {
        let directory = requested ?? (terminals.isEmpty ? Preferences.startingDirectory : activeTerminal.currentDirectory)
        let session = TerminalSession(initialDirectory: directory)
        session.onDirectoryChange = { [weak self, weak session] url in
            guard let self, let session, session.id == self.selectedTerminalID else { return }
            self.terminalCwd = url
        }
        terminals.append(session)
        selectedTerminalID = session.id
        // Typed ahead: the shell reads it once its startup files have loaded and PATH is set.
        session.send("claude\r")
    }

    func requestCloseTerminal(_ id: UUID) {
        guard let index = terminals.firstIndex(where: { $0.id == id }) else { return }
        let session = terminals[index]

        let alert = NSAlert()
        alert.messageText = "Close terminal \"\(session.currentDirectory.lastPathComponent)\"?"
        alert.informativeText = "The running shell and any processes in it will be terminated."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        session.close()
        terminals.remove(at: index)
        if terminals.isEmpty {
            newTerminal()
        } else if selectedTerminalID == id {
            selectedTerminalID = terminals[min(index, terminals.count - 1)].id
        }
    }

    func requestCloseActiveTerminal() {
        requestCloseTerminal(activeTerminal.id)
    }

    var linkedTab: ExplorerTab { explorerTabs[0] }

    var selectedTab: ExplorerTab {
        explorerTabs.first { $0.id == selectedTabID } ?? linkedTab
    }

    func openTab(_ url: URL) {
        let tab = ExplorerTab(rootURL: url, isTerminalLinked: false, showHidden: showHidden)
        explorerTabs.append(tab)
        selectedTabID = tab.id
    }

    func closeTab(_ id: UUID) {
        guard let index = explorerTabs.firstIndex(where: { $0.id == id }),
              !explorerTabs[index].isTerminalLinked else { return }
        explorerTabs[index].stopWatching()
        explorerTabs.remove(at: index)
        if selectedTabID == id {
            selectedTabID = explorerTabs[min(index, explorerTabs.count - 1)].id
        }
    }

    func closeSelectedTabOrWindow() {
        if selectedTab.isTerminalLinked {
            NSApp.keyWindow?.performClose(nil)
        } else {
            closeTab(selectedTabID)
        }
    }

    func chooseFolderForNewTab() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = selectedTab.root.url
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(openTab)
    }

    func cdTerminal(to url: URL) {
        let quoted = "'" + url.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        activeTerminal.send(" cd \(quoted)\r")
        activeTerminal.focus()
    }
}
