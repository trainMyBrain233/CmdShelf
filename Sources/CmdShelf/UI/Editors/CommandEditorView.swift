import AppKit
import SwiftUI

struct CommandEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let original: Command?
    private let availableGroups: [String]
    private let onSave: (Command) -> Void
    private let onTestRun: ((String) -> Void)?

    @State private var title: String
    @State private var groupName: String
    @State private var description: String
    @State private var content: String
    @State private var shell: String
    @State private var riskLevel: Int
    @State private var isPinned: Bool
    @State private var validationMessage: String?
    @State private var testRunMessage: String?

    private let shellPresets = ["zsh", "bash", "python"]

    init(
        command: Command?,
        availableGroups: [String] = [],
        onSave: @escaping (Command) -> Void,
        onTestRun: ((String) -> Void)? = nil
    ) {
        self.original = command
        self.availableGroups = availableGroups
        self.onSave = onSave
        self.onTestRun = onTestRun

        _title = State(initialValue: command?.title ?? "")
        let initialGroup = command?.groupName ?? availableGroups.first ?? "General"
        _groupName = State(initialValue: initialGroup)
        _description = State(initialValue: command?.description ?? "")
        _content = State(initialValue: command?.content ?? "")
        _shell = State(initialValue: command?.shell ?? "any")
        _riskLevel = State(initialValue: command?.riskLevel ?? 0)
        _isPinned = State(initialValue: command?.isPinned ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Form {
                Section {
                    TextField("例如：重建索引并重启服务", text: $title)
                    Picker("分组", selection: $groupName) {
                        ForEach(groupOptions, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("描述（可选）", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("基本信息")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shell")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField("zsh / bash / python", text: $shell)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    applyTopShellSuggestion()
                                }

                            Menu {
                                ForEach(shellPresets, id: \.self) { preset in
                                    Button(preset) {
                                        shell = preset
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .menuStyle(.borderlessButton)
                        }

                        if !filteredShellSuggestions.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(filteredShellSuggestions, id: \.self) { suggestion in
                                    Button(suggestion) {
                                        shell = suggestion
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }

                    Picker("风险等级", selection: $riskLevel) {
                        Text("Safe").tag(0)
                        Text("Warn").tag(1)
                        Text("Danger").tag(2)
                    }
                    .pickerStyle(.menu)

                    Toggle("置顶收藏", isOn: $isPinned)
                } header: {
                    Text("脚本执行")
                }

                Section("命令内容") {
                    commandEditorSection
                }
            }
            .formStyle(.grouped)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )

            HStack {
                if let testRunMessage {
                    Text(testRunMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    commitPendingEditsThenSave()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 560, height: 460)
        .alert("Cannot Save Command", isPresented: isValidationAlertPresented) {
            Button("OK", role: .cancel) {
                validationMessage = nil
            }
        } message: {
            Text(validationMessage ?? "Please fill in required fields.")
        }
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

    private var filteredShellSuggestions: [String] {
        let keyword = shell.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return [] }
        return shellPresets.filter { preset in
            let lower = preset.lowercased()
            return lower.hasPrefix(keyword) && lower != keyword
        }
    }

    private var isValidationAlertPresented: Binding<Bool> {
        Binding(
            get: { validationMessage != nil },
            set: { newValue in
                if !newValue {
                    validationMessage = nil
                }
            }
        )
    }

    private var commandEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("命令脚本")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("这里填写将被复制执行的命令内容。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    runTest()
                } label: {
                    Image(systemName: "play.circle")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("测试运行")
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.15, alpha: 1.0)))

                TextEditor(text: $content)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.95))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(minHeight: 140)

                if content.isEmpty {
                    Text("例如：\\ngit pull origin main\\nswift build -c release")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 14)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
    }

    private func applyTopShellSuggestion() {
        guard let top = filteredShellSuggestions.first else { return }
        shell = top
    }

    private func saveIfValid() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTitle.isEmpty else {
            validationMessage = "Title is required."
            return
        }

        let base = original
        let command = Command(
            id: base?.id ?? UUID(),
            title: normalizedTitle,
            content: content,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description,
            shell: shell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "any" : shell,
            riskLevel: riskLevel,
            groupName: groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : groupName,
            isPinned: isPinned,
            copyCount: base?.copyCount ?? 0,
            lastCopiedAt: base?.lastCopiedAt,
            createdAt: base?.createdAt ?? Date(),
            updatedAt: Date()
        )
        onSave(command)
        dismiss()
    }

    private func commitPendingEditsThenSave() {
        // Ensure TextEditor/IME composition is committed before validation.
        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
            content = textView.string
        }
        NSApp.keyWindow?.endEditing(for: nil)
        saveIfValid()
    }

    private func runTest() {
        commitPendingEdits()
        let script = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !script.isEmpty else {
            testRunMessage = "请输入命令后再测试运行。"
            return
        }
        onTestRun?(script)
        testRunMessage = "已触发测试运行（预览模式）。"
    }

    private func commitPendingEdits() {
        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
            content = textView.string
        }
        NSApp.keyWindow?.endEditing(for: nil)
    }
}
