import AppKit
import CoreGraphics
import Foundation

@MainActor
final class ActivityMonitor {
    var onSnapshot: ((ActivitySnapshot) -> Void)?
    var onInactivity: ((Date) -> Void)?
    var onAutomationMessage: ((String?) -> Void)?
    var onInputMonitoringMessage: ((String?) -> Void)?

    private let browserURLProvider: BrowserURLProvider
    private let pollingInterval: TimeInterval
    private let idleThreshold: TimeInterval

    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?

    init(
        browserURLProvider: BrowserURLProvider = BrowserURLProvider(),
        pollingInterval: TimeInterval = 5,
        idleThreshold: TimeInterval = 300
    ) {
        self.browserURLProvider = browserURLProvider
        self.pollingInterval = pollingInterval
        self.idleThreshold = idleThreshold
    }

    func start() {
        guard timer == nil else { return }

        updateInputMonitoringMessage()
        capture()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.capture()
            }
        }

        let timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.capture()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
    }

    func requestInputMonitoringAccess() {
        let granted = CGRequestListenEventAccess()
        if granted {
            onInputMonitoringMessage?(nil)
        } else {
            updateInputMonitoringMessage()
        }
    }

    private func capture() {
        let now = Date()

        guard !isIdle else {
            onInactivity?(now)
            return
        }

        guard
            let app = NSWorkspace.shared.frontmostApplication,
            let appName = app.localizedName,
            !appName.isEmpty
        else {
            onInactivity?(now)
            return
        }

        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            onInactivity?(now)
            return
        }

        var webURL: String?
        var pageTitle: String?

        do {
            if let browserContext = try browserURLProvider.currentContext(for: appName, bundleIdentifier: app.bundleIdentifier) {
                webURL = browserContext.urlString
                pageTitle = browserContext.pageTitle
            }
            onAutomationMessage?(nil)
        } catch let error as BrowserAutomationIssue {
            onAutomationMessage?(error.errorDescription)
        } catch {
            onAutomationMessage?("Nao foi possivel consultar o navegador ativo.")
        }

        onSnapshot?(
            ActivitySnapshot(
                timestamp: now,
                applicationName: appName,
                bundleIdentifier: app.bundleIdentifier,
                webURL: webURL,
                pageTitle: pageTitle
            )
        )
    }

    private var isIdle: Bool {
        guard CGPreflightListenEventAccess() else {
            return false
        }

        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null) > idleThreshold
    }

    private func updateInputMonitoringMessage() {
        guard !CGPreflightListenEventAccess() else {
            onInputMonitoringMessage?(nil)
            return
        }

        onInputMonitoringMessage?("Sem permissao de Monitoramento de Entrada. O luum continua lendo app e URL, mas nao consegue pausar a captura quando voce fica ausente.")
    }
}
