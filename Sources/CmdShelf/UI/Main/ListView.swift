import SwiftUI

struct ListView: View {
    @EnvironmentObject private var appState: AppState

    @State private var presentingCommandEditor = false
    @State private var presentingSopEditor = false
    @State private var editingCommand: Command?
    @State private var editingSop: Sop?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("Section", selection: $appState.activeTab) {
                    ForEach(MainTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)

                Spacer()

                switch appState.activeTab {
                case .commands:
                    Button {
                        editingCommand = nil
                        presentingCommandEditor = true
                    } label: {
                        Label("New Command", systemImage: "plus")
                    }
                    .disabled(!appState.isDatabaseConnected)

                    Button {
                        if let selected = appState.selectedCommand {
                            editingCommand = selected
                            presentingCommandEditor = true
                        }
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .disabled(appState.selectedCommand == nil || !appState.isDatabaseConnected)

                    Button(role: .destructive) {
                        if let id = appState.selectedCommandID {
                            Task {
                                await appState.deleteCommand(id: id)
                            }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(appState.selectedCommandID == nil || !appState.isDatabaseConnected)

                case .sops:
                    Button {
                        editingSop = nil
                        presentingSopEditor = true
                    } label: {
                        Label("New SOP", systemImage: "plus")
                    }
                    .disabled(!appState.isDatabaseConnected)

                    Button {
                        if let selected = appState.selectedSop {
                            editingSop = selected
                            presentingSopEditor = true
                        }
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .disabled(appState.selectedSop == nil || !appState.isDatabaseConnected)

                    Button(role: .destructive) {
                        if let id = appState.selectedSopID {
                            Task {
                                await appState.deleteSop(id: id)
                            }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(appState.selectedSopID == nil || !appState.isDatabaseConnected)

                case .inbox:
                    EmptyView()
                }
            }
            .padding(.horizontal, 8)

            Group {
                switch appState.activeTab {
                case .commands:
                    commandList
                case .sops:
                    sopList
                case .inbox:
                    InboxView(embedded: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(8)
        .sheet(isPresented: $presentingCommandEditor) {
            CommandEditorView(command: editingCommand) { command in
                Task {
                    _ = await appState.saveCommand(command)
                }
            }
        }
        .sheet(isPresented: $presentingSopEditor) {
            SopEditorView(sop: editingSop) { sop in
                Task {
                    _ = await appState.saveSop(sop)
                }
            }
        }
    }

    private var commandList: some View {
        List {
            ForEach(appState.filteredCommands, id: \.id) { command in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(command.title)
                            .font(.body)
                            .lineLimit(1)
                        if command.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    HStack(spacing: 8) {
                        Text(command.groupName)
                        Text("copy: \(command.copyCount)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .tag(command.id)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.selectedCommandID = command.id
                    appState.selectedSopID = nil
                }
                .contextMenu {
                    Button("Copy") {
                        appState.copyCommand(command)
                    }
                    Button("Edit") {
                        editingCommand = command
                        presentingCommandEditor = true
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var sopList: some View {
        List {
            ForEach(appState.filteredSops, id: \.id) { sop in
                VStack(alignment: .leading, spacing: 4) {
                    Text(sop.title)
                        .font(.body)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(sop.groupName)
                        Text("copy: \(sop.copyCount)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .tag(sop.id)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.selectedSopID = sop.id
                    appState.selectedCommandID = nil
                }
                .contextMenu {
                    Button("Open") {
                        appState.selectedSopID = sop.id
                        appState.activeTab = .sops
                    }
                    Button("Edit") {
                        editingSop = sop
                        presentingSopEditor = true
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}
