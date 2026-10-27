import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .padding(.top, 8)

            VStack(spacing: 4) {
                Button {
                    let panelWindow = NSApp.keyWindow
                    dismissMenuBarPanel(window: panelWindow)
                    DispatchQueue.main.async {
                        openWindow(id: "main")
                        appState.openMainWindow()
                    }
                } label: {
                    rowLabel(
                        icon: "macwindow",
                        title: "Open Main Window"
                    )
                }
                .buttonStyle(MenuButtonStyle())

                Button {
                    let panelWindow = NSApp.keyWindow
                    dismissMenuBarPanel(window: panelWindow)
                    DispatchQueue.main.async {
                        appState.openPaletteFromMenuBar()
                    }
                } label: {
                    rowLabel(
                        icon: "command",
                        title: "Open Command Palette"
                    )
                }
                .buttonStyle(MenuButtonStyle())

                quickCopyTop5Section

                Button {
                    let panelWindow = NSApp.keyWindow
                    dismissMenuBarPanel(window: panelWindow)
                    DispatchQueue.main.async {
                        openWindow(id: "main")
                        appState.activeTab = .inbox
                        appState.openMainWindow()
                    }
                } label: {
                    rowLabel(
                        icon: "tray.full",
                        title: "Inbox",
                        badge: appState.inboxItems.count
                    )
                }
                .buttonStyle(MenuButtonStyle())
            }
            .padding(.top, 8)

            Divider()
                .padding(.vertical, 8)

            VStack(spacing: 4) {
                settingsRow

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    rowLabel(
                        icon: "power",
                        title: "Quit CmdShelf",
                        footer: true
                    )
                }
                .buttonStyle(MenuButtonStyle())
            }
        }
        .padding(12)
        .frame(width: 304)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20, height: 20)

            Text("CmdShelf")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    @ViewBuilder
    private var settingsRow: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                rowLabel(
                    icon: "gearshape",
                    title: "Settings",
                    footer: true
                )
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    let panelWindow = NSApp.keyWindow
                    appState.prepareForSettingsOpen()
                    dismissMenuBarPanel(window: panelWindow)
                }
            )
            .buttonStyle(MenuButtonStyle())
        } else {
            Button {
                let panelWindow = NSApp.keyWindow
                dismissMenuBarPanel(window: panelWindow)
                DispatchQueue.main.async {
                    appState.openSettingsWindowLegacy()
                }
            } label: {
                rowLabel(
                    icon: "gearshape",
                    title: "Settings",
                    footer: true
                )
            }
            .buttonStyle(MenuButtonStyle())
        }
    }

    private var topThreeCommands: [Command] {
        Array(appState.topCommands.prefix(3))
    }

    @ViewBuilder
    private var quickCopyTop5Section: some View {
        if topThreeCommands.isEmpty {
            rowLabel(
                icon: "flame.fill",
                title: "Quick Copy: Most Used",
                subtitle: "No commands yet"
            )
            .opacity(0.6)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 4) {
                rowLabel(
                    icon: "flame.fill",
                    title: "Quick Copy: Top 3 Most Used"
                )
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 2)

                ForEach(topThreeCommands, id: \.id) { command in
                    Button {
                        appState.copyCommand(command)
                    } label: {
                        rowLabel(
                            icon: "terminal",
                            title: command.title,
                            subtitle: command.groupName,
                            trailingText: "\(command.copyCount)"
                        )
                    }
                    .buttonStyle(MenuButtonStyle())
                }
            }
        }
    }

    private func dismissMenuBarPanel(window: NSWindow?) {
        dismiss()
        DispatchQueue.main.async {
            window?.close()
        }
    }

    private func rowLabel(
        icon: String,
        title: String,
        subtitle: String? = nil,
        trailingText: String? = nil,
        badge: Int? = nil,
        footer: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: footer ? 12 : 14, weight: .semibold))
                .foregroundStyle(footer ? .secondary : .primary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: footer ? 12 : 13, weight: .semibold))
                    .foregroundStyle(footer ? .secondary : .primary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 8)

            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if let badge, badge > 0 {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .clipShape(Capsule())
            }

        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuButtonBody(configuration: configuration)
    }

    private struct MenuButtonBody: View {
        let configuration: Configuration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundColor)
                )
                .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
                .onHover { hovering in
                    isHovering = hovering
                }
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }

        private var backgroundColor: Color {
            if configuration.isPressed {
                return Color.accentColor.opacity(0.16)
            }
            if isHovering {
                return Color.accentColor.opacity(0.10)
            }
            return Color.clear
        }
    }
}

struct MenuBarRootView: View {
    var body: some View {
        MenuBarView()
    }
}
