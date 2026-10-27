import SwiftUI

struct AppToast: Identifiable, Equatable {
    enum Style {
        case success
        case info
        case error

        var backgroundColor: Color {
            switch self {
            case .success:
                return Color.green.opacity(0.92)
            case .info:
                return Color.blue.opacity(0.92)
            case .error:
                return Color.red.opacity(0.92)
            }
        }
    }

    let id = UUID()
    let message: String
    let style: Style
    let icon: String
}

struct AppToastView: View {
    let toast: AppToast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.icon)
                .font(.system(size: 12, weight: .semibold))
            Text(toast.message)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(toast.style.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}
