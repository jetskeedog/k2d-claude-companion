import Foundation
import Observation

@MainActor
@Observable
final class ExplorerTab: Identifiable {
    let id = UUID()
    /// The sticky first tab: follows the terminal's working directory and cannot be closed.
    let isTerminalLinked: Bool
    private(set) var root: FileNode
    var selection: URL?

    init(rootURL: URL, isTerminalLinked: Bool, showHidden: Bool) {
        self.isTerminalLinked = isTerminalLinked
        root = Self.makeRoot(rootURL, showHidden: showHidden)
    }

    var title: String {
        let name = root.name
        return isTerminalLinked ? "Terminal: \(name)" : name
    }

    func setRoot(_ url: URL, showHidden: Bool) {
        guard url.standardizedFileURL != root.url.standardizedFileURL else { return }
        root.stopWatching()
        root = Self.makeRoot(url, showHidden: showHidden)
        selection = nil
    }

    func reload(showHidden: Bool) {
        root.setShowHidden(showHidden)
    }

    func stopWatching() {
        root.stopWatching()
    }

    private static func makeRoot(_ url: URL, showHidden: Bool) -> FileNode {
        let node = FileNode(url: url.standardizedFileURL, isDirectory: true, showHidden: showHidden)
        node.isExpanded = true
        return node
    }
}
