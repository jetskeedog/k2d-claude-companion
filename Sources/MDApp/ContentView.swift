import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HSplitView {
            FavoritesSidebar()
                .frame(minWidth: 150, idealWidth: 200, maxWidth: 320)

            VSplitView {
                ExplorerPane()
                    .frame(minHeight: 160, idealHeight: 380)
                ViewerPane()
                    .frame(minHeight: 160, idealHeight: 480)
            }
            .frame(minWidth: 280, idealWidth: 520)

            TerminalTabsView()
                .frame(minWidth: 360, idealWidth: 880, maxHeight: .infinity)
        }
    }
}
