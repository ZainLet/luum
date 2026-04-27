import AppKit
import SwiftUI
import UserNotifications

final class LUUMAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
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
            }
        }

        Settings {
            SettingsView(store: store)
                .frame(width: 760, height: 760)
                .tint(LuumTheme.accent)
        }
    }
}
