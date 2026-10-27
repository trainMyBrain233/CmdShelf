import SwiftUI

struct ContentListView: View {
    @ObservedObject var viewModel: CmdShelfWorkspaceViewModel
    var onEditCommand: (Command) -> Void = { _ in }
    var onDeleteCommand: (Command) -> Void = { _ in }
    var onEditSop: (Sop) -> Void = { _ in }
    var onDeleteSop: (Sop) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 12) {
            searchBar

            if viewModel.visibleItems.isEmpty {
                emptyListState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.visibleItems) { item in
                            CommandRowView(
                                item: item,
                                isSelected: viewModel.isSelected(item)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.12)) {
                                    viewModel.select(item)
                                }
                            }
                            .contextMenu {
                                rowContextMenu(for: item)
                            }
                        }
                    }
                    .padding(.bottom, 70)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func rowContextMenu(for item: CmdShelfDesign.LibraryItem) -> some View {
        switch item {
        case .command(let command):
            Button("Copy") {
                viewModel.copy(item: item)
            }
            Button("Edit") {
                onEditCommand(command)
            }
            Button("Delete", role: .destructive) {
                onDeleteCommand(command)
            }

        case .sop(let sop):
            Button("Copy") {
                viewModel.copy(item: item)
            }
            Button("Edit") {
                onEditSop(sop)
            }
            Button("Delete", role: .destructive) {
                onDeleteSop(sop)
            }

        case .inbox(let inbox):
            Button("Copy") {
                viewModel.copy(item: item)
            }
            Divider()
            Button("Save As Command") {
                viewModel.convertInboxToCommand(inbox)
            }
            Button("Save As SOP") {
                viewModel.convertInboxToSop(inbox)
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteInbox(inbox)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            AppKitSearchField(
                text: $viewModel.searchText,
                placeholder: "Search commands and SOPs"
            )
            .frame(height: 28)

            Menu {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(CmdShelfWorkspaceViewModel.ContentFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private var emptyListState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text("No Results")
                .font(.headline)
            Text("Try a different keyword or filter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
