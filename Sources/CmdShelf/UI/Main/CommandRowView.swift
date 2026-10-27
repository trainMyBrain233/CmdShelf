import SwiftUI

struct CommandRowView: View {
    let item: CmdShelfDesign.LibraryItem
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: item.kindIcon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.preview)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                if case .inbox = item {
                    Text("Inbox")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("🔥 \(item.uses) uses")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text(item.updatedAt, format: .relative(presentation: .named))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.08), lineWidth: 1)
        )
    }
}
