import MarkdownUI
import SwiftUI

struct SopEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let original: Sop?
    private let availableGroups: [String]
    private let onSave: (Sop) -> Void

    @State private var title: String
    @State private var groupName: String
    @State private var bodyMarkdown: String
    @State private var showPreview: Bool = false

    init(sop: Sop?, availableGroups: [String] = [], onSave: @escaping (Sop) -> Void) {
        self.original = sop
        self.availableGroups = availableGroups
        self.onSave = onSave

        _title = State(initialValue: sop?.title ?? "")
        let initialGroup = sop?.groupName ?? availableGroups.first ?? "General"
        _groupName = State(initialValue: initialGroup)
        _bodyMarkdown = State(initialValue: sop?.bodyMarkdown ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(original == nil ? "New SOP" : "Edit SOP")
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                TextField("Title", text: $title)
                Picker("Group", selection: $groupName) {
                    ForEach(groupOptions, id: \.self) { group in
                        Text(group).tag(group)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Preview", isOn: $showPreview)

                if showPreview {
                    ScrollView {
                        Markdown(bodyMarkdown)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 220)
                } else {
                    TextEditor(text: $bodyMarkdown)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 220)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    let base = original
                    let sop = Sop(
                        id: base?.id ?? UUID(),
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        bodyMarkdown: bodyMarkdown,
                        groupName: groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : groupName,
                        copyCount: base?.copyCount ?? 0,
                        lastUsedAt: base?.lastUsedAt,
                        createdAt: base?.createdAt ?? Date(),
                        updatedAt: Date()
                    )
                    onSave(sop)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 700, minHeight: 560)
    }

    private var groupOptions: [String] {
        var seen = Set<String>()
        var groups = (availableGroups + [groupName, "General"])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { group in
                let lowered = group.lowercased()
                if seen.contains(lowered) {
                    return false
                }
                seen.insert(lowered)
                return true
            }
            .sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }

        if let generalIndex = groups.firstIndex(where: { $0.caseInsensitiveCompare("General") == .orderedSame }) {
            let general = groups.remove(at: generalIndex)
            groups.insert(general, at: 0)
        }

        return groups
    }
}
