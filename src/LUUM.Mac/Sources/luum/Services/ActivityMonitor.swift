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
    private let browserContextRefreshInterval: TimeInterval

    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var cachedBrowserContext: CachedBrowserContext?
    private var isRunning = false
    private var captureTaskScheduled = false
    private var pendingForceBrowserRefresh = false

    init(
        browserURLProvider: BrowserURLProvider = BrowserURLProvider(),
        pollingInterval: TimeInterval = 8,
        idleThreshold: TimeInterval = 300,
        browserContextRefreshInterval: TimeInterval = 12
    ) {
        self.browserURLProvider = browserURLProvider
        self.pollingInterval = pollingInterval
        self.idleThreshold = idleThreshold
        self.browserContextRefreshInterval = browserContextRefreshInterval
    }

    func start() {
        guard timer == nil else { return }
        isRunning = true

        updateInputMonitoringMessage()
        capture()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleCapture(forceBrowserRefresh: true)
            }
        }

        let timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleCapture()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        captureTaskScheduled = false
        pendingForceBrowserRefresh = false

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

    private func scheduleCapture(forceBrowserRefresh: Bool = false) {
        guard isRunning else { return }
        pendingForceBrowserRefresh = pendingForceBrowserRefresh || forceBrowserRefresh
        guard !captureTaskScheduled else { return }

        captureTaskScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard isRunning else {
                captureTaskScheduled = false
                pendingForceBrowserRefresh = false
                return
            }
            let forceRefresh = pendingForceBrowserRefresh
            pendingForceBrowserRefresh = false
            captureTaskScheduled = false
            capture(forceBrowserRefresh: forceRefresh)
        }
    }

    private func capture(forceBrowserRefresh: Bool = false) {
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
            if let browserContext = try browserContext(
                for: appName,
                bundleIdentifier: app.bundleIdentifier,
                now: now,
                forceRefresh: forceBrowserRefresh
            ) {
                webURL = browserContext.urlString
                pageTitle = browserContext.pageTitle
            }
            onAutomationMessage?(nil)
        } catch let error as BrowserAutomationIssue {
            onAutomationMessage?(error.errorDescription)
        } catch {
            onAutomationMessage?("Não foi possível consultar o navegador ativo.")
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

        onInputMonitoringMessage?("Sem permissão de Monitoramento de Entrada. O luum continua lendo app e URL, mas não consegue pausar a captura quando você fica ausente.")
    }

    private func browserContext(
        for applicationName: String,
        bundleIdentifier: String?,
        now: Date,
        forceRefresh: Bool
    ) throws -> BrowserContext? {
        let cacheKey = "\(bundleIdentifier ?? "")|\(applicationName)"

        if !forceRefresh,
           let cachedBrowserContext,
           cachedBrowserContext.cacheKey == cacheKey,
           now.timeIntervalSince(cachedBrowserContext.capturedAt) < browserContextRefreshInterval {
            return cachedBrowserContext.context
        }

        let context = try browserURLProvider.currentContext(for: applicationName, bundleIdentifier: bundleIdentifier)
        cachedBrowserContext = CachedBrowserContext(cacheKey: cacheKey, context: context, capturedAt: now)
        return context
    }
}

private struct CachedBrowserContext {
    let cacheKey: String
    let context: BrowserContext?
    let capturedAt: Date
}
