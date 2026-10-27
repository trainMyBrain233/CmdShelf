import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var appState: AppState

    var embedded: Bool = false

    @State private var draftCommand: Command?
    @State private var draftSop: Sop?
    @State private var pendingDeletionInboxID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if !embedded {
                    Text("Inbox")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                Button {
                    Task {
                        await appState.captureClipboardToInbox()
                    }
                } label: {
                    Label("Capture Clipboard", systemImage: "tray.and.arrow.down")
                }
                .disabled(!appState.isDatabaseConnected)
            }

            List {
                ForEach(appState.inboxItems, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.summary)
                                .lineLimit(1)
                            Spacer()
                            Text(item.detectedType.rawValue.uppercased())
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Button("Save as Command") {
                                draftCommand = Command(
                                    title: "Inbox Command",
                                    content: item.rawText,
                                    description: "Imported from Inbox",
                                    groupName: "General"
                                )
                                pendingDeletionInboxID = item.id
                            }
                            .disabled(!appState.isDatabaseConnected)

                            Button("Save as SOP") {
                                draftSop = Sop(
                                    title: "Inbox SOP",
                                    bodyMarkdown: item.rawText,
                                    groupName: "General"
                                )
                                pendingDeletionInboxID = item.id
                            }
                            .disabled(!appState.isDatabaseConnected)

                            Button("Delete", role: .destructive) {
                                Task {
                                    await appState.deleteInboxItem(id: item.id)
                                }
                            }
                            .disabled(!appState.isDatabaseConnected)
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    .tag(item.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectedInboxID = item.id
                    }
                }
            }
            .listStyle(.inset)
        }
        .sheet(item: $draftCommand) { command in
            CommandEditorView(command: command) { saved in
                Task {
                    let didSave = await appState.saveCommand(saved)
                    if didSave, let inboxID = pendingDeletionInboxID ?? appState.selectedInboxID {
                        await appState.deleteInboxItem(id: inboxID)
                    }
                    pendingDeletionInboxID = nil
                }
            }
        }
        .sheet(item: $draftSop) { sop in
            SopEditorView(sop: sop) { saved in
                Task {
                    let didSave = await appState.saveSop(saved)
                    if didSave, let inboxID = pendingDeletionInboxID ?? appState.selectedInboxID {
                        await appState.deleteInboxItem(id: inboxID)
                    }
                    pendingDeletionInboxID = nil
                }
            }
        }
    }
}
