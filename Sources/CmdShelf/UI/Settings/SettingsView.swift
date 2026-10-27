import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            databaseTab
                .tabItem {
                    Label("Database", systemImage: "server.rack")
                }
        }
        .frame(width: 500, height: 400)
    }

    private var generalTab: some View {
        Form {
            Section {
                LabeledContent("Open Main Window") {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        KeyboardShortcuts.Recorder("", name: .openMainWindow)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.thinMaterial)
                    )
                }
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("Set the global shortcut for opening the main workspace instantly.")
            }

            Section("Application") {
                LabeledContent("Version") {
                    Text(versionText)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Migration Status") {
                    Text(appState.migrationStatusText)
                        .fontWeight(.semibold)
                        .foregroundStyle(migrationStatusColor)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var databaseTab: some View {
        Form {
            Section {
                LabeledContent("Host") {
                    Text(MySQLConfig.embeddedHost)
                        .foregroundStyle(.secondary)
                        .frame(width: 220)
                }

                LabeledContent("Port") {
                    Text("\(MySQLConfig.embeddedPort)")
                        .foregroundStyle(.secondary)
                        .frame(width: 220)
                }

                LabeledContent("Username") {
                    Text(MySQLConfig.embeddedUsername)
                        .foregroundStyle(.secondary)
                        .frame(width: 220)
                }

                LabeledContent("Database") {
                    Text(MySQLConfig.embeddedDatabase)
                        .foregroundStyle(.secondary)
                        .frame(width: 220)
                }

                LabeledContent("Password") {
                    Text("Environment variable")
                        .foregroundStyle(.secondary)
                        .frame(width: 220)
                }
            } header: {
                Text("Connection Config")
            } footer: {
                Text("Configured by CMDSHELF_MYSQL_* environment variables (read-only).")
            }

            Section("Connection Status") {
                HStack(spacing: 10) {
                    Circle()
                        .fill(appState.isDatabaseConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(connectionStatusText)
                        .fontWeight(.semibold)

                    Spacer()

                    Button("Retry Connection") {
                        Task {
                            await appState.testConnection()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var connectionStatusText: String {
        appState.isDatabaseConnected
            ? "Connected to \(MySQLConfig.embeddedHost)"
            : "Disconnected from \(MySQLConfig.embeddedHost)"
    }

    private var migrationStatusColor: Color {
        appState.migrationStatusText.lowercased().contains("ready") ? .green : .secondary
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
