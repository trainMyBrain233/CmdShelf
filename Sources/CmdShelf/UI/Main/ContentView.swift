import SwiftUI

struct ContentView: View {
    private enum UndoItem {
        case command(Command)
        case sop(Sop)
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CmdShelfWorkspaceViewModel()
    @AppStorage("cmdshelf.ui.sidebar.visible") private var isSidebarVisible = true
    @State private var presentingCommandEditor = false
    @State private var presentingSopEditor = false
    @State private var editingCommand: Command?
    @State private var editingSop: Sop?
    @State private var pendingDeleteCommand: Command?
    @State private var pendingDeleteSop: Sop?
    @State private var pendingUndoItem: UndoItem?
    @State private var undoDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            if shouldShowDisconnectedBanner {
                disconnectedBanner
            }

            splitWorkspace
        }
        .overlay(alignment: .bottomTrailing) {
            if pendingUndoItem != nil {
                undoToastOverlay
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                viewModel.attach(appState: appState)
            }
            DispatchQueue.main.async {
                appState.ensureMainWindowFocused()
            }
        }
        .onChange(of: appState.commands) { _ in
            scheduleSync()
        }
        .onChange(of: appState.sops) { _ in
            scheduleSync()
        }
        .onChange(of: appState.inboxItems) { _ in
            scheduleSync()
        }
        .onChange(of: appState.dbStatus) { _ in
            scheduleSync()
        }
        .onChange(of: appState.customGroups) { _ in
            scheduleSync()
        }
        .onDisappear {
            undoDismissTask?.cancel()
        }
        .sheet(isPresented: $presentingCommandEditor) {
            CommandEditorView(
                command: editingCommand,
                availableGroups: appState.availableGroups
            ) { command in
                viewModel.saveCommand(command)
            }
        }
        .sheet(isPresented: $presentingSopEditor) {
            SopEditorView(
                sop: editingSop,
                availableGroups: appState.availableGroups
            ) { sop in
                viewModel.saveSop(sop)
            }
        }
        .alert("Delete Command?", isPresented: isDeleteCommandAlertPresented) {
            Button("Delete", role: .destructive) {
                guard let command = pendingDeleteCommand else { return }
                viewModel.deleteCommand(command)
                registerUndo(.command(command))
                pendingDeleteCommand = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteCommand = nil
            }
        } message: {
            Text(deleteCommandMessage)
        }
        .alert("Delete SOP?", isPresented: isDeleteSopAlertPresented) {
            Button("Delete", role: .destructive) {
                guard let sop = pendingDeleteSop else { return }
                viewModel.deleteSop(sop)
                registerUndo(.sop(sop))
                pendingDeleteSop = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteSop = nil
            }
        } message: {
            Text(deleteSopMessage)
        }
    }

    private var shouldShowDisconnectedBanner: Bool {
        appState.hasCompletedInitialBootstrap
            && appState.dbStatus == .disconnected
            && !viewModel.isDatabaseConnected
    }

    private var splitWorkspace: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                SidebarView(viewModel: viewModel)
                    .frame(minWidth: 220, maxWidth: 220, maxHeight: .infinity, alignment: .topLeading)

                Divider()
                    .opacity(0.25)
            }

            ContentListView(
                viewModel: viewModel,
                onEditCommand: { command in
                    beginEditing(command: command)
                },
                onDeleteCommand: { command in
                    pendingDeleteCommand = command
                },
                onEditSop: { sop in
                    beginEditing(sop: sop)
                },
                onDeleteSop: { sop in
                    pendingDeleteSop = sop
                }
            )
            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()
                .opacity(0.25)

            DetailView(
                viewModel: viewModel,
                onEditCommand: { command in
                    beginEditing(command: command)
                },
                onDeleteCommand: { command in
                    pendingDeleteCommand = command
                },
                onEditSop: { sop in
                    beginEditing(sop: sop)
                },
                onDeleteSop: { sop in
                    pendingDeleteSop = sop
                }
            )
            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebarWithoutAnimation()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    beginCreatingCommand()
                } label: {
                    Label("New Command", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!viewModel.isDatabaseConnected)
                .tint(Color(nsColor: NSColor(calibratedRed: 0.36, green: 0.55, blue: 1.0, alpha: 1.0)))
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    beginCreatingSop()
                } label: {
                    Label("New SOP", systemImage: "doc.badge.plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!viewModel.isDatabaseConnected)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.10),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func toggleSidebarWithoutAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isSidebarVisible.toggle()
        }
    }

    private var disconnectedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Database disconnected")
                .fontWeight(.semibold)
            Spacer()
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Open Settings")
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        appState.prepareForSettingsOpen()
                    }
                )
            } else {
                Button("Open Settings") {
                    appState.openSettingsWindowLegacy()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.18))
    }

    private func scheduleSync() {
        DispatchQueue.main.async {
            viewModel.sync(from: appState)
        }
    }

    private var isDeleteCommandAlertPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteCommand != nil },
            set: { newValue in
                if !newValue {
                    pendingDeleteCommand = nil
                }
            }
        )
    }

    private var isDeleteSopAlertPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteSop != nil },
            set: { newValue in
                if !newValue {
                    pendingDeleteSop = nil
                }
            }
        )
    }

    private var deleteCommandMessage: String {
        guard let command = pendingDeleteCommand else {
            return "This action cannot be undone."
        }
        return "\"\(command.title)\" will be deleted. You can undo shortly after deletion."
    }

    private var deleteSopMessage: String {
        guard let sop = pendingDeleteSop else {
            return "This action cannot be undone."
        }
        return "\"\(sop.title)\" will be deleted. You can undo shortly after deletion."
    }

    private func beginCreatingCommand() {
        editingCommand = nil
        presentingCommandEditor = true
    }

    private func beginEditing(command: Command) {
        editingCommand = command
        presentingCommandEditor = true
    }

    private func beginCreatingSop() {
        editingSop = nil
        presentingSopEditor = true
    }

    private func beginEditing(sop: Sop) {
        editingSop = sop
        presentingSopEditor = true
    }

    private var undoToastOverlay: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text(undoBannerText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button("Undo") {
                performUndo()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.white.opacity(0.22))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .padding(.trailing, 16)
        .padding(.bottom, appState.currentToast == nil ? 16 : 70)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var undoBannerText: String {
        switch pendingUndoItem {
        case .command(let command):
            return "Deleted command \"\(command.title)\"."
        case .sop(let sop):
            return "Deleted SOP \"\(sop.title)\"."
        case .none:
            return ""
        }
    }

    private func registerUndo(_ item: UndoItem) {
        pendingUndoItem = item
        undoDismissTask?.cancel()
        undoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                pendingUndoItem = nil
            }
        }
    }

    private func performUndo() {
        guard let pendingUndoItem else { return }
        undoDismissTask?.cancel()
        self.pendingUndoItem = nil

        switch pendingUndoItem {
        case .command(let command):
            viewModel.saveCommand(command)
        case .sop(let sop):
            viewModel.saveSop(sop)
        }
    }
}
