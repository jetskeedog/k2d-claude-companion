import SwiftUI

/// Directory hot keys: double-clicking a favorite (or pressing ⌘1–⌘9) opens it in a new explorer
/// tab and a new terminal tab. A single click only selects, so removal never opens anything.
struct FavoritesSidebar: View {
    @Environment(AppState.self) private var state
    @State private var selection: URL?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            List(selection: $selection) {
                ForEach(Array(state.favorites.enumerated()), id: \.element) { index, url in
                    row(url, index: index)
                }
            }
            .listStyle(.sidebar)
            .overlay {
                if state.favorites.isEmpty {
                    Text("Click + to add a folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .contextMenu(forSelectionType: URL.self) { urls in
                if let url = urls.first {
                    Button("Open in New Tabs") { state.openFavorite(url) }
                    Button("Remove from Favorites…") {
                        if state.requestRemoveFavorite(url), selection == url { selection = nil }
                    }
                }
            } primaryAction: { urls in
                if let url = urls.first { state.openFavorite(url) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Favorites")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button { state.chooseFavorite() } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .help("Add a folder to Favorites")
            Button {
                if let selection, state.requestRemoveFavorite(selection) { self.selection = nil }
            } label: { Image(systemName: "minus") }
                .buttonStyle(.borderless)
                .disabled(selection == nil)
                .help("Remove the selected favorite")
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(.bar)
    }

    private func row(_ url: URL, index: Int) -> some View {
        HStack {
            Label(url.lastPathComponent, systemImage: "folder")
                .lineLimit(1)
            Spacer()
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .tag(url)
        .help(url.path)
    }
}
