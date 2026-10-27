import AppKit
import MarkdownUI
import SwiftUI

struct DetailView: View {
    @ObservedObject var viewModel: CmdShelfWorkspaceViewModel
    var onEditCommand: (Command) -> Void = { _ in }
    var onDeleteCommand: (Command) -> Void = { _ in }
    var onEditSop: (Sop) -> Void = { _ in }
    var onDeleteSop: (Sop) -> Void = { _ in }
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let item = viewModel.selectedItem {
                itemDetail(item)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func itemDetail(_ item: CmdShelfDesign.LibraryItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(for: item)

                switch item {
                case .command(let command):
                    commandBlock(command)
                case .sop(let sop):
                    sopBlock(sop)
                case .inbox(let inbox):
                    inboxBlock(inbox)
                }

                metadataRow(for: item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private func header(for item: CmdShelfDesign.LibraryItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.system(size: 34, weight: .bold))
                .lineLimit(2)

            HStack(spacing: 8) {
                tagCapsule(item.category)
                tagCapsule(item.typeLabel)
                Text("Updated \(item.updatedAt, format: .relative(presentation: .named))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func commandBlock(_ command: Command) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Command")
                    .font(.headline)
                Spacer()
                Button {
                    onEditCommand(command)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!viewModel.isDatabaseConnected)

                Button(role: .destructive) {
                    onDeleteCommand(command)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!viewModel.isDatabaseConnected)

                Button {
                    viewModel.copy(item: .command(command))
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text(command.content)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .textSelection(.enabled)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private func sopBlock(_ sop: Sop) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SOP")
                    .font(.headline)
                Spacer()
                Button {
                    onEditSop(sop)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!viewModel.isDatabaseConnected)

                Button(role: .destructive) {
                    onDeleteSop(sop)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!viewModel.isDatabaseConnected)

                Button {
                    viewModel.copy(item: .sop(sop))
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Markdown(sop.bodyMarkdown)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private func inboxBlock(_ inbox: InboxItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Inbox Capture")
                    .font(.headline)
                Spacer()
                Button {
                    copyRawText(inbox.rawText)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(inbox.rawText)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .textSelection(.enabled)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            HStack(spacing: 10) {
                Button("Save As Command") {
                    viewModel.convertInboxToCommand(inbox)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Save As SOP") {
                    viewModel.convertInboxToSop(inbox)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Delete", role: .destructive) {
                    viewModel.deleteInbox(inbox)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func metadataRow(for item: CmdShelfDesign.LibraryItem) -> some View {
        switch item {
        case .inbox(let inbox):
            return AnyView(
                HStack(spacing: 12) {
                    statCard(title: "Detected Type", value: inbox.detectedType.rawValue.uppercased())
                    statCard(title: "Captured", value: inbox.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
            )
        case .command, .sop:
            return AnyView(
                HStack(spacing: 12) {
                    statCard(title: "Total Copies", value: "\(item.uses)")
                    statCard(title: "Created", value: item.createdAt.formatted(date: .abbreviated, time: .omitted))
                    statCard(title: "Last Updated", value: item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "command.square")
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Nothing Selected")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Pick an item from the list.\nPress ⌘+N to create.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var codeBackground: some ShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color.black.opacity(0.45))
            : AnyShapeStyle(Color.white.opacity(0.75))
    }

    private func tagCapsule(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(Color.accentColor)
            .background(Color.accentColor.opacity(0.14))
            .clipShape(Capsule())
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func copyRawText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
