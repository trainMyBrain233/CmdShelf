import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var appState: AppState

    @State private var query: String = ""
    @State private var results: [SearchResult] = []
    @State private var selectedResultID: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var hasSearched = false

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search commands and SOPs", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onSubmit {
                    runPrimaryAction()
                }

            List(selection: $selectedResultID) {
                ForEach(results, id: \.id) { result in
                    PaletteRowView(result: result)
                        .tag(result.id)
                }
            }
            .listStyle(.inset)

            HStack {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Enter: primary  Cmd+Enter: open detail  Esc: close")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            Button(action: runOpenDetailAction) {
                EmptyView()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .opacity(0.001)
            .frame(width: 0, height: 0)
        )
        .onExitCommand {
            appState.closePalette()
        }
        .onAppear {
            isSearchFocused = true
            refreshResults(immediate: true)
        }
        .onChange(of: query) { _ in
            refreshResults()
        }
        .onChange(of: appState.paletteFocusNonce) { _ in
            isSearchFocused = true
            refreshResults(immediate: true)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func refreshResults(immediate: Bool = false) {
        searchTask?.cancel()
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        searchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 180_000_000)
                if Task.isCancelled { return }
            }

            await MainActor.run {
                isSearching = true
            }
            let newResults = await appState.searchPalette(query: currentQuery, limit: 20)
            if Task.isCancelled { return }

            await MainActor.run {
                results = newResults
                hasSearched = true
                isSearching = false
                if let selectedResultID, results.contains(where: { $0.id == selectedResultID }) {
                    return
                }
                selectedResultID = results.first?.id
            }
        }
    }

    private func selectedResult() -> SearchResult? {
        guard let selectedResultID else { return results.first }
        return results.first { $0.id == selectedResultID } ?? results.first
    }

    private func runPrimaryAction() {
        guard let result = selectedResult() else { return }

        switch result {
        case .command(let command):
            appState.copyCommand(command)
            appState.closePalette()
        case .sop:
            runOpenDetailAction()
        }
    }

    private func runOpenDetailAction() {
        guard let result = selectedResult() else { return }
        appState.focusOn(result: result)
        appState.closePalette()
    }

    private var statusText: String {
        if isSearching {
            return "Searching..."
        }
        if hasSearched && results.isEmpty {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "No commands or SOPs yet"
            }
            return "No results"
        }
        return "Ready"
    }
}
