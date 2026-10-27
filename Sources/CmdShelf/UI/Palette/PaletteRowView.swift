import SwiftUI

struct PaletteRowView: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 10) {
            Text(result.typeLabel)
                .font(.caption2.monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(result.typeLabel == "CMD" ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.body)
                    .lineLimit(1)
                Text(result.groupName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(result.copyCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
