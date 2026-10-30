import AppKit
import SwiftUI

enum Preferences {
    static let startingDirectoryKey = "startingDirectory"
    private static let favoritesKey = "favorites"

    /// Falls back to the home folder when unset or when the saved folder no longer exists.
    static var startingDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let path = UserDefaults.standard.string(forKey: startingDirectoryKey), !path.isEmpty else { return home }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return home }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static var favorites: [URL] {
        get {
            (UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
                .map { URL(fileURLWithPath: $0, isDirectory: true) }
        }
        set { UserDefaults.standard.set(newValue.map(\.path), forKey: favoritesKey) }
    }
}

struct SettingsView: View {
    @AppStorage(Preferences.startingDirectoryKey) private var startingPath = ""

    var body: some View {
        Form {
            LabeledContent("Starting directory:") {
                HStack {
                    Text(startingPath.isEmpty ? "Home (~)" : abbreviated(startingPath))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .help(startingPath.isEmpty ? FileManager.default.homeDirectoryForCurrentUser.path : startingPath)
                    Spacer()
                    Button("Choose…") { choose() }
                    Button("Reset") { startingPath = "" }
                        .disabled(startingPath.isEmpty)
                }
            }
            Text("The explorer and the first terminal tab open here when the app launches.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 520)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use as Starting Directory"
        panel.directoryURL = Preferences.startingDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        startingPath = url.standardizedFileURL.path
    }

    private func abbreviated(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
