import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LoadedFile {
    enum Content {
        case text(String, lang: String?)
        case markdown(String)
        case image(NSImage)
        case unsupported(String)
    }

    let url: URL
    let loadID = UUID()
    let content: Content
}

struct ViewerPane: View {
    @Environment(AppState.self) private var state
    @State private var loaded: LoadedFile?
    @State private var reloadToken = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: TaskKey(url: state.openFile, token: reloadToken)) {
            guard let url = state.openFile else {
                loaded = nil
                return
            }
            let file = await Task.detached(priority: .userInitiated) { FileLoader.load(url) }.value
            if !Task.isCancelled { loaded = file }
        }
    }

    private struct TaskKey: Equatable {
        var url: URL?
        var token: Int
    }

    private var header: some View {
        @Bindable var state = state
        return HStack(spacing: 8) {
            if let url = state.openFile {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 0) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(url.deletingLastPathComponent().path)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer()
                if case .markdown = loaded?.content {
                    Picker("", selection: $state.mdMode) {
                        Text("Raw").tag(MarkdownMode.raw)
                        Text("Read").tag(MarkdownMode.read)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .help("Toggle raw / rendered (⌘R)")
                }
                Button { reloadToken += 1 } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("Reload from disk")
                Button { state.openFile = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .help("Close file")
            } else {
                Text("Viewer").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        if let loaded, loaded.url == state.openFile {
            switch loaded.content {
            case let .text(text, lang):
                WebViewer(payload: WebPayload(id: "\(loaded.loadID)", mode: .code, text: text, lang: lang),
                          onOpenFile: open)
            case let .markdown(text):
                WebViewer(
                    payload: WebPayload(
                        id: "\(loaded.loadID)-\(state.mdMode.rawValue)",
                        mode: state.mdMode == .read ? .markdown : .code,
                        text: text,
                        lang: "markdown",
                        baseURL: loaded.url.deletingLastPathComponent()
                    ),
                    onOpenFile: open
                )
            case let .image(image):
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image).padding()
                }
            case let .unsupported(reason):
                placeholder(reason, systemImage: "doc.questionmark")
            }
        } else if state.openFile == nil {
            placeholder("Select a file in the explorer to view it", systemImage: "doc.text.magnifyingglass")
        } else {
            ProgressView().controlSize(.small)
        }
    }

    private func open(_ url: URL) { state.openFile = url }

    private func placeholder(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.system(size: 28)).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
    }
}

enum FileLoader {
    static let maxTextBytes = 5 * 1024 * 1024

    static func load(_ url: URL) -> LoadedFile {
        LoadedFile(url: url, content: content(for: url))
    }

    private static func content(for url: URL) -> LoadedFile.Content {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .isDirectoryKey])
        if values?.isDirectory == true { return .unsupported("This is a folder") }
        let type = values?.contentType

        if let type, type.conforms(to: .image), !type.conforms(to: .svg) {
            if let image = NSImage(contentsOf: url) { return .image(image) }
        }
        if let size = values?.fileSize, size > maxTextBytes {
            return .unsupported("File is too large to preview (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))")
        }
        guard let data = try? Data(contentsOf: url) else {
            return .unsupported("Could not read file")
        }
        if data.prefix(8192).contains(0) {
            return .unsupported("Binary file — no preview available")
        }
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)

        let ext = url.pathExtension.lowercased()
        if ["md", "markdown", "mdown", "mkd", "mdx"].contains(ext) {
            return .markdown(text)
        }
        return .text(text, lang: language(for: url))
    }

    static func language(for url: URL) -> String? {
        let name = url.lastPathComponent.lowercased()
        switch name {
        case "makefile", "gnumakefile": return "makefile"
        case "dockerfile": return "dockerfile"
        case "cmakelists.txt": return "cmake"
        case ".zshrc", ".zshenv", ".zprofile", ".bashrc", ".bash_profile", ".profile": return "bash"
        case ".gitignore", ".gitattributes", ".env": return "plaintext"
        default: break
        }
        let ext = url.pathExtension.lowercased()
        let map: [String: String] = [
            "txt": "plaintext", "log": "plaintext",
            "h": "c", "hpp": "cpp", "hh": "cpp", "cc": "cpp", "m": "objectivec", "mm": "objectivec",
            "zsh": "bash", "command": "bash",
            "jsx": "javascript", "mjs": "javascript", "cjs": "javascript", "tsx": "typescript", "mts": "typescript",
            "vue": "xml", "html": "xml", "htm": "xml", "plist": "xml", "svg": "xml", "xib": "xml", "storyboard": "xml",
            "yml": "yaml", "toml": "ini", "cfg": "ini", "conf": "ini",
            "kt": "kotlin", "kts": "kotlin", "gradle": "groovy", "rs": "rust", "rb": "ruby", "py": "python",
            "pl": "perl", "cs": "csharp", "ps1": "powershell", "jsonc": "json", "json5": "json",
        ]
        if let lang = map[ext] { return lang }
        return ext.isEmpty ? nil : ext
    }
}
