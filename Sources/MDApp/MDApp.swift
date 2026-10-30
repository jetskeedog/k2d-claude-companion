import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable via `swift run`.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let iconURL = Bundle.module.url(forResource: "K2Dapp", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct MDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        Window("K2D Claude Agent", id: "main") {
            ContentView()
                .environment(state)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1400, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder in New Tab…") { state.chooseFolderForNewTab() }
                    .keyboardShortcut("o")
                Button("New Terminal Tab") { state.newTerminal() }
                    .keyboardShortcut("t")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Close Tab") { state.closeSelectedTabOrWindow() }
                    .keyboardShortcut("w")
                Button("Close Terminal Tab…") { state.requestCloseActiveTerminal() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
            }
            CommandMenu("View Options") {
                Button(state.mdMode == .read ? "Show Raw Markdown" : "Show Rendered Markdown") {
                    state.mdMode.toggle()
                }
                .keyboardShortcut("r")
                Button(state.showHidden ? "Hide Hidden Files" : "Show Hidden Files") {
                    state.showHidden.toggle()
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])
            }
            CommandMenu("Favorites") {
                Button("Add Favorite…") { state.chooseFavorite() }
                Divider()
                ForEach(Array(state.favorites.prefix(9).enumerated()), id: \.element) { index, url in
                    Button(url.lastPathComponent) { state.openFavorite(url) }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
