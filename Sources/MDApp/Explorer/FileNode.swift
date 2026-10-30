import Foundation
import Observation

@MainActor
@Observable
final class FileNode: Identifiable {
    let url: URL
    let isDirectory: Bool
    private(set) var children: [FileNode]?
    var isExpanded = false {
        didSet {
            guard isExpanded != oldValue else { return }
            if isExpanded { loadChildren() } else { stopWatching() }
        }
    }

    @ObservationIgnored private var watcher: DirectoryWatcher?
    @ObservationIgnored private var showHidden: Bool

    nonisolated var id: URL { url }
    var name: String { url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent }

    init(url: URL, isDirectory: Bool, showHidden: Bool) {
        self.url = url
        self.isDirectory = isDirectory
        self.showHidden = showHidden
    }

    /// Children to hand to `List`/`OutlineGroup`: nil for files so no disclosure arrow is drawn.
    var outlineChildren: [FileNode]? {
        guard isDirectory else { return nil }
        return children ?? []
    }

    func loadChildren() {
        guard isDirectory else { return }
        refresh()
        if watcher == nil {
            watcher = DirectoryWatcher(url: url) { [weak self] in self?.refresh() }
        }
    }

    func setShowHidden(_ value: Bool) {
        showHidden = value
        guard children != nil else { return }
        refresh()
        children?.forEach { $0.setShowHidden(value) }
    }

    /// Re-reads the directory while keeping existing child nodes (and their expansion state).
    func refresh() {
        guard isDirectory else { return }
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        let urls = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: options)) ?? []

        let existing = Dictionary((children ?? []).map { ($0.url, $0) }, uniquingKeysWith: { a, _ in a })
        var next: [FileNode] = urls.map { child in
            if let node = existing[child] { return node }
            let values = try? child.resourceValues(forKeys: Set(keys))
            let isDir = (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
            return FileNode(url: child, isDirectory: isDir, showHidden: showHidden)
        }
        next.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        let removed = Set(existing.keys).subtracting(next.map(\.url))
        removed.forEach { existing[$0]?.stopWatching() }
        children = next
    }

    func stopWatching() {
        watcher = nil
        children?.forEach { $0.stopWatching() }
    }
}
