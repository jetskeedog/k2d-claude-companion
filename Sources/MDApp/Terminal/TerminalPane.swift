import AppKit
import Observation
import SwiftTerm
import SwiftUI

/// One terminal tab. Owns the terminal view and shell process until the tab is closed, so
/// SwiftUI re-rendering never restarts the shell.
@MainActor
@Observable
final class TerminalSession: NSObject, Identifiable, LocalProcessTerminalViewDelegate {
    let id = UUID()
    let createdAt = Date()
    @ObservationIgnored let view: LocalProcessTerminalView
    @ObservationIgnored var onDirectoryChange: ((URL) -> Void)?
    private(set) var currentDirectory: URL
    @ObservationIgnored private var isClosing = false

    init(initialDirectory: URL) {
        currentDirectory = initialDirectory
        view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        super.init()
        view.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        view.processDelegate = self
        startShell()
    }

    private func startShell() {
        let launch = ShellIntegration.launchConfiguration()
        view.startProcess(
            executable: launch.executable,
            args: launch.args,
            environment: launch.environment,
            execName: launch.execName,
            currentDirectory: currentDirectory.path
        )
    }

    func send(_ text: String) {
        view.send(txt: text)
    }

    func focus() {
        view.window?.makeFirstResponder(view)
    }

    func close() {
        isClosing = true
        view.terminate()
    }

    // MARK: LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory, let url = Self.parseOSC7(directory) else { return }
        currentDirectory = url
        onDirectoryChange?(url)
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard !isClosing else { return }
        view.feed(text: "\r\n[Process exited\(exitCode.map { " with code \($0)" } ?? ""). Starting a new shell…]\r\n\r\n")
        startShell()
    }

    /// Accepts `file://host/path` (raw or percent-encoded) as well as a bare path.
    static func parseOSC7(_ value: String) -> URL? {
        var path = value
        if path.hasPrefix("file://") {
            path.removeFirst("file://".count)
            guard let slash = path.firstIndex(of: "/") else { return nil }
            path = String(path[slash...])
        }
        guard path.hasPrefix("/") else { return nil }
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
           let decoded = path.removingPercentEncoding {
            path = decoded
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }
}

struct TerminalPane: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        embed(in: container)
        DispatchQueue.main.async { session.focus() }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if session.view.superview !== nsView { embed(in: nsView) }
    }

    private func embed(in container: NSView) {
        let terminal = session.view
        terminal.removeFromSuperview()
        terminal.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: container.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
}
