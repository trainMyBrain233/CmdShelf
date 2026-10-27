import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: CmdShelfWorkspaceViewModel
    @State private var isAddingGroup = false
    @State private var newGroupName = ""
    @State private var renamingGroupName: String?
    @State private var renamedGroupDraft = ""
    @State private var pendingDeleteGroupName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                sectionTitle("Library")
                VStack(spacing: 6) {
                    sidebarItem("All Commands", icon: "terminal", selection: .allCommands)
                    sidebarItem("SOPs", icon: "doc.text", selection: .sops)
                    sidebarItem("Inbox", icon: "tray", selection: .inbox, badge: viewModel.inboxUnreadCount)
                }

                sectionTitle("Smart Lists")
                VStack(spacing: 6) {
                    sidebarItem("Most Used", icon: "flame.fill", selection: .mostUsed)
                    sidebarItem("Recently Added", icon: "clock", selection: .recentlyAdded)
                }

                groupSection
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
        .background(
            ZStack {
                Rectangle().fill(.thinMaterial)
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.10),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
        .alert("Delete Group?", isPresented: isDeleteGroupAlertPresented) {
            Button("Delete", role: .destructive) {
                guard let group = pendingDeleteGroupName else { return }
                viewModel.deleteGroup(named: group)
                if case .tag(let selectedTag) = viewModel.sidebarSelection,
                   selectedTag.caseInsensitiveCompare(group) == .orderedSame {
                    viewModel.sidebarSelection = .allCommands
                }
                pendingDeleteGroupName = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteGroupName = nil
            }
        } message: {
            Text(deleteGroupMessage)
        }
    }

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                sectionTitle("Tags / Groups")
                Spacer(minLength: 0)
                Button {
                    startAddingGroup()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help("Add Group")
            }

            VStack(spacing: 6) {
                if isAddingGroup {
                    groupEditorRow(
                        title: "New Group",
                        value: $newGroupName,
                        onConfirm: commitAddGroup,
                        onCancel: cancelAddingGroup
                    )
                }

                ForEach(viewModel.categories) { category in
                    if renamingGroupName?.caseInsensitiveCompare(category.name) == .orderedSame {
                        groupEditorRow(
                            title: "Rename Group",
                            value: $renamedGroupDraft,
                            onConfirm: commitRenameGroup,
                            onCancel: cancelRenamingGroup
                        )
                    } else {
                        sidebarItem(
                            category.name,
                            icon: category.symbol,
                            selection: .tag(category.name)
                        )
                        .contextMenu {
                            Button("Rename") {
                                startRenamingGroup(category.name)
                            }
                            Button("Delete", role: .destructive) {
                                pendingDeleteGroupName = category.name
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
    }

    private func groupEditorRow(
        title: String,
        value: Binding<String>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tag.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            TextField(title, text: value)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    onConfirm()
                }

            Button {
                onConfirm()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.borderless)

            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private func sidebarItem(
        _ title: String,
        icon: String,
        selection: CmdShelfWorkspaceViewModel.SidebarSelection,
        badge: Int? = nil
    ) -> some View {
        let isSelected = viewModel.sidebarSelection == selection

        return Button {
            viewModel.sidebarSelection = selection
            viewModel.selectedItemID = viewModel.visibleItems.first?.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var isDeleteGroupAlertPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteGroupName != nil },
            set: { newValue in
                if !newValue {
                    pendingDeleteGroupName = nil
                }
            }
        )
    }

    private var deleteGroupMessage: String {
        guard let group = pendingDeleteGroupName else {
            return "This action cannot be undone."
        }
        return "\"\(group)\" will be deleted and its items will be moved to General."
    }

    private func startAddingGroup() {
        renamingGroupName = nil
        renamedGroupDraft = ""
        isAddingGroup = true
    }

    private func cancelAddingGroup() {
        isAddingGroup = false
        newGroupName = ""
    }

    private func commitAddGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addGroup(named: trimmed)
        isAddingGroup = false
        newGroupName = ""
    }

    private func startRenamingGroup(_ originalName: String) {
        isAddingGroup = false
        newGroupName = ""
        renamingGroupName = originalName
        renamedGroupDraft = originalName
    }

    private func cancelRenamingGroup() {
        renamingGroupName = nil
        renamedGroupDraft = ""
    }

    private func commitRenameGroup() {
        guard let oldName = renamingGroupName else { return }
        let trimmed = renamedGroupDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.renameGroup(from: oldName, to: trimmed)
        renamingGroupName = nil
        renamedGroupDraft = ""
    }
}
