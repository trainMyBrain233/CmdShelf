import AppKit
import SwiftUI

@main
struct CmdShelfApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window("CmdShelf", id: "main") {
            MainWindowView()
                .environmentObject(appState)
                .background(WindowAccessor { window in
                    appState.assignMainWindow(window)
                })
                .task {
                    await appState.bootstrapIfNeeded()
                }
                .overlay(alignment: .bottomTrailing) {
                    toastOverlay
                }
                .alert(item: $appState.currentError) { error in
                    Alert(
                        title: Text("Error"),
                        message: Text(error.errorDescription ?? "Unknown error"),
                        dismissButton: .default(Text("OK"))
                    )
                }
        }
        .defaultPosition(.center)
        .defaultSize(width: 1060, height: 700)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .background(WindowAccessor { window in
                    appState.assignSettingsWindow(window)
                })
                .task {
                    await appState.bootstrapIfNeeded()
                }
                .frame(width: 500, height: 400)
                .overlay(alignment: .bottomTrailing) {
                    toastOverlay
                }
                .alert(item: $appState.currentError) { error in
                    Alert(
                        title: Text("Error"),
                        message: Text(error.errorDescription ?? "Unknown error"),
                        dismissButton: .default(Text("OK"))
                    )
                }
        }

        MenuBarExtra("CmdShelf", systemImage: "terminal") {
            MenuBarView()
                .environmentObject(appState)
                .task {
                    await appState.bootstrapIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: appState.currentToast) { toast in
            guard let toast else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if appState.currentToast?.id == toast.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        appState.currentToast = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = appState.currentToast {
            AppToastView(toast: toast)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}
