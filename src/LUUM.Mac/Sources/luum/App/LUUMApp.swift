import AppKit
import Sparkle
import SwiftUI
import UserNotifications

final class LUUMAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var updaterController: SPUStandardUpdaterController?

    @MainActor var updater: SPUUpdater? { updaterController?.updater }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        UNUserNotificationCenter.current().delegate = self
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        CrashReportService.install()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        DispatchQueue.main.async {
            Task { @MainActor in
                NSApp.windows.forEach { Self.configureWindow($0) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task { @MainActor in
                Self.normalizeInitialWindows()
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    @objc
    private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString)
        else { return }

        NotificationCenter.default.post(name: .luumAuthCallbackReceived, object: url)
    }

    @objc
    private func handleWindowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            Self.configureWindow(window)
        }
    }

    @MainActor
    private static func configureWindow(_ window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.toolbarStyle = .unifiedCompact
        window.backgroundColor = NSColor(
            calibratedRed: 0.04,
            green: 0.03,
            blue: 0.08,
            alpha: 1
        )
    }

    @MainActor
    private static func normalizeInitialWindows() {
        let mainWindow = NSApp.windows.first { $0.title == "Luum" }
        let feedbackWindows = NSApp.windows.filter { $0.title == "Reportar Problema" }

        guard let mainWindow, !feedbackWindows.isEmpty else { return }

        feedbackWindows.forEach { $0.close() }
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct LUUMApp: App {
    @NSApplicationDelegateAdaptor(LUUMAppDelegate.self) private var appDelegate
    @State private var store = ActivityStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Luum", id: "main") {
            Group {
                if hasCompletedOnboarding {
                    ContentView(store: store)
                        .frame(minWidth: 1280, minHeight: 820)
                } else {
                    OnboardingView(store: store) {
                        hasCompletedOnboarding = true
                    }
                    .frame(width: 760, height: 600)
                }
            }
            .tint(LuumTheme.accent)
            .task {
                store.bootstrap()
            }
            .onOpenURL { url in
                store.handleAuthCallbackURL(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .luumAuthCallbackReceived)) { notification in
                guard let url = notification.object as? URL else { return }
                store.handleAuthCallbackURL(url)
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
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: appDelegate.updater)
            }
            CommandGroup(replacing: .help) {
                Button("Reportar problema...") {
                    openWindow(id: "feedback")
                }
            }
        }

        Window("Reportar Problema", id: "feedback") {
            FeedbackView(store: store)
                .fixedSize()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView(store: store)
                .frame(width: 760, height: 760)
                .tint(LuumTheme.accent)
        }

        MenuBarExtra("Luum", systemImage: store.isMonitoring ? "sparkles" : "pause.circle") {
            MenuBarPanel(store: store)
                .frame(width: 320)
                .padding(14)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarPanel: View {
    @Bindable var store: ActivityStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Luum")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Circle()
                    .fill(store.isMonitoring ? LuumTheme.electricBlue : LuumTheme.textMuted)
                    .frame(width: 10, height: 10)
            }

            Text(store.currentActivityTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(store.currentActivityCategory?.title ?? "Aguardando atividade")
                .font(.caption)
                .foregroundStyle(store.currentActivityCategory?.tint ?? LuumTheme.textSecondary)

            Text("Sessão atual: \(LuumFormatters.duration(store.currentActivityDuration))")
                .font(.caption)
                .foregroundStyle(LuumTheme.textSecondary)

            if let currentFocusBlockMatch = store.currentFocusBlockMatch {
                Label(currentFocusBlockMatch.title, systemImage: "hand.raised.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LuumTheme.hotPink)
                    .lineLimit(2)
            } else if let focusShieldStatusMessage = store.focusShieldStatusMessage {
                Text(focusShieldStatusMessage)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let todaySummary = store.summary(for: Date())
            if todaySummary.totalTrackedTime > 0 {
                Divider()
                    .overlay(.white.opacity(0.06))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Hoje: \(LuumFormatters.duration(todaySummary.totalTrackedTime))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LuumTheme.textSecondary)

                    ForEach(todaySummary.categoryBreakdown.prefix(3)) { breakdown in
                        HStack {
                            Circle()
                                .fill(breakdown.category.tint)
                                .frame(width: 6, height: 6)
                            Text(breakdown.category.title)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text(LuumFormatters.duration(breakdown.duration))
                                .font(.caption)
                                .foregroundStyle(LuumTheme.textSecondary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            Divider()
                .overlay(.white.opacity(0.06))

            HStack(spacing: 10) {
                Button(store.isMonitoring ? "Pausar" : "Iniciar") {
                    store.toggleMonitoring()
                }
                .buttonStyle(.glassProminent)

                Button("Abrir app") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                .buttonStyle(.bordered)
            }

            Menu("Classificar atividade atual") {
                ForEach(store.categories) { category in
                    Button {
                        store.overrideCurrentActivityCategory(categoryID: category.id)
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                    }
                }
            }
            .menuStyle(.borderlessButton)
            if let focusModeStatusMessage = store.focusModeStatusMessage {
                Divider()
                    .overlay(.white.opacity(0.06))

                Text(focusModeStatusMessage)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LuumTheme.elevatedBlack.opacity(0.96))
        )
    }
}
