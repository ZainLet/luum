import AppKit
import SwiftUI

final class LUUMAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct LUUMApp: App {
    @NSApplicationDelegateAdaptor(LUUMAppDelegate.self) private var appDelegate
    @State private var store = ActivityStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1280, minHeight: 820)
                .tint(LuumTheme.accent)
                .task {
                    store.bootstrap()
                }
        }
        .defaultSize(width: 1440, height: 920)
        .commands {
            CommandMenu("Monitoramento") {
                Button(store.isMonitoring ? "Pausar Captura" : "Iniciar Captura") {
                    store.toggleMonitoring()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Divider()

                Button("Abrir Preferencias") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView(store: store)
                .frame(width: 760, height: 760)
                .tint(LuumTheme.accent)
        }
    }
}
