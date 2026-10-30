import SwiftUI

struct TerminalTabsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            TerminalTabStrip()
            Divider()
            TerminalPane(session: state.activeTerminal)
                .id(state.activeTerminal.id)
        }
    }
}

private struct TerminalTabStrip: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(state.terminals) { session in
                        TerminalTabButton(session: session, isSelected: session.id == state.activeTerminal.id)
                    }
                }
                .padding(.horizontal, 6)
            }
            Button { state.newTerminal() } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .help("New terminal tab (⌘T)")
                .padding(.trailing, 8)
        }
        .frame(height: 30)
        .background(.bar)
    }
}

private struct TerminalTabButton: View {
    @Environment(AppState.self) private var state
    let session: TerminalSession
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "terminal")
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            Text(session.currentDirectory.lastPathComponent)
                .lineLimit(1)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            Text(session.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                .lineLimit(1)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Button { state.requestCloseTerminal(session.id) } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.borderless)
            .opacity(isHovering || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : (isHovering ? Color.primary.opacity(0.06) : .clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { state.selectedTerminalID = session.id }
        .onHover { isHovering = $0 }
        .help(session.currentDirectory.path)
    }
}
