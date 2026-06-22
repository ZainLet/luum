import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ActivityStore {
    private(set) var samples: [ActivitySample]
    private(set) var isMonitoring = false
    private(set) var currentSnapshot: ActivitySnapshot?
    private(set) var automationStatusMessage: String?
    private(set) var inputMonitoringMessage: String?
    private(set) var notificationPermissionMessage: String?
    private(set) var notificationsAuthorized = false
    private(set) var lastReminderStatusMessage: String?
    private(set) var focusModeStatusMessage: String?
    private(set) var focusShieldStatusMessage: String?
    private(set) var currentFocusBlockMatch: FocusBlockMatch?
    private(set) var exportStatusMessage: String?
    private(set) var authSession: LuumAuthSession?
    private(set) var authStatusMessage: String?
    private(set) var isCheckingAuth = false

    private(set) var monitoringPreferences: MonitoringPreferencesSnapshot

    var googleCalendarClientID: String
    var googleCalendarClientSecret: String
    private(set) var googleCalendarConnections: [GoogleCalendarConnectionSnapshot]
    private(set) var googleCalendarStatusMessage: String?
    private(set) var isConnectingGoogleCalendar = false
    private(set) var isSyncingGoogleCalendar = false
    private(set) var notionCalendarStatusMessage: String?
    private(set) var notionAgendaItems: [CalendarAgendaItem] = []
    private(set) var isSyncingNotionCalendar = false
    private(set) var outlookCalendarStatusMessage: String?
    private(set) var outlookAgendaItems: [CalendarAgendaItem] = []
    private(set) var isSyncingOutlookCalendar = false
    private(set) var clickUpStatusMessage: String?
    private(set) var clickUpAgendaItems: [CalendarAgendaItem] = []
    private(set) var isSyncingClickUp = false
    private(set) var linearStatusMessage: String?
    private(set) var linearAgendaItems: [CalendarAgendaItem] = []
    private(set) var isSyncingLinear = false
    private(set) var zapierStatusMessage: String?

    private(set) var cloudSyncStatusMessage: String?
    private(set) var cloudSyncLastSyncAt: Date?
    private(set) var isSyncingCloud = false
    private(set) var workspaceSyncStatusMessage: String?
    private(set) var workspaceSyncLastSyncAt: Date?
    private(set) var workspaceRankingEntries: [TeamRankingEntry] = []
    private(set) var isSyncingWorkspace = false
    private(set) var aiClassificationStatusMessage: String?
    private(set) var isClassifyingWithAI = false
    private(set) var isSendingWeeklyReportEmail = false
    private(set) var weeklyReportEmailHealthMessage: String?
    private(set) var isCheckingWeeklyReportEmailHealth = false
    private(set) var publicIntegrationConfig: PublicIntegrationConfig?
    private(set) var publicIntegrationStatusMessage: String?
    private(set) var isLoadingPublicIntegrationConfig = false

    let classifier = ClassificationEngine()

    @ObservationIgnored private let persistence: ActivityPersistence
    @ObservationIgnored private let monitor: ActivityMonitor
    @ObservationIgnored private let googleCalendarPersistence: GoogleCalendarPersistence
    @ObservationIgnored private let googleCalendarService: GoogleCalendarService
    @ObservationIgnored private let notionCalendarService: NotionCalendarService
    @ObservationIgnored private let outlookCalendarService: OutlookCalendarService
    @ObservationIgnored private let clickUpService: ClickUpService
    @ObservationIgnored private let linearService: LinearService
    @ObservationIgnored private let zapierService: ZapierService
    @ObservationIgnored private let monitoringPreferencesPersistence: MonitoringPreferencesPersistence
    @ObservationIgnored private let reminderEngine: ReminderEngine
    @ObservationIgnored private let keychainService: KeychainService
    @ObservationIgnored private let cloudSyncService: CloudSyncService
    @ObservationIgnored private let workspaceSyncService: WorkspaceSyncService
    @ObservationIgnored private let authService: FirebaseAuthService
    @ObservationIgnored private let aiClassificationService: AIClassificationService
    @ObservationIgnored private let weeklyReportEmailService: WeeklyReportEmailService
    @ObservationIgnored private let publicIntegrationConfigService: PublicIntegrationConfigService
    @ObservationIgnored private let sessionGapTolerance: TimeInterval = 15
    @ObservationIgnored private var calendarTokensByConnectionID: [String: GoogleCalendarTokens] = [:]
    @ObservationIgnored private var summaryCache: [Date: DailySummary] = [:]
    @ObservationIgnored private var focusModeDeliveries: [UUID: Date] = [:]
    @ObservationIgnored private var focusBlockDeliveries: [String: Date] = [:]
    @ObservationIgnored private var persistTask: Task<Void, Never>?
    @ObservationIgnored private var persistenceWriteTask: Task<Void, Never>?
    @ObservationIgnored private var preferencesWriteTask: Task<Void, Never>?
    @ObservationIgnored private var reminderEvaluationTask: Task<Void, Never>?
    @ObservationIgnored private var lastReminderEvaluationRequestAt: Date?
    @ObservationIgnored private var authRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var authRefreshGeneration = 0
    @ObservationIgnored private var cloudSyncTask: Task<Void, Never>?
    @ObservationIgnored private var cloudSyncPendingAfterCurrent = false
    @ObservationIgnored private var workspaceSyncTask: Task<Void, Never>?
    @ObservationIgnored private var aiClassificationTask: Task<Void, Never>?
    @ObservationIgnored private var weeklyReportEmailTask: Task<Void, Never>?
    @ObservationIgnored private var weeklyReportEmailHealthTask: Task<Void, Never>?
    @ObservationIgnored private var maintenanceTask: Task<Void, Never>?
    @ObservationIgnored private var lastAuthCallbackSignature: String?
    @ObservationIgnored private var lastCompletedAuthState: String?
    @ObservationIgnored private var pendingAuthRequest: LuumAuthRequest?
    @ObservationIgnored private let calendarRefreshInterval: TimeInterval = 900
    @ObservationIgnored private let cloudSyncInterval: TimeInterval = 900
    @ObservationIgnored private let reminderEvaluationMinimumInterval: TimeInterval = 30
    @ObservationIgnored private let activityPersistenceDebounce: Duration
    @ObservationIgnored private let preferencesPersistenceDebounce: Duration = .milliseconds(300)
    @ObservationIgnored private let liveSummaryRefreshInterval: TimeInterval = 30
    @ObservationIgnored private var lastLiveSummaryRefreshAt: Date?
    @ObservationIgnored private var notionAgendaDay: Date?
    @ObservationIgnored private var outlookAgendaDay: Date?
    @ObservationIgnored private var clickUpAgendaDay: Date?
    @ObservationIgnored private var linearAgendaDay: Date?
    private(set) var summaryRevision = 0

    @ObservationIgnored private static let notionPendingConnectionMessage = "Conexao Notion em um clique sera liberada em breve."
    @ObservationIgnored private static let outlookPendingConnectionMessage = "Conexao Microsoft em um clique sera liberada em breve."
    @ObservationIgnored private static let clickUpPendingConnectionMessage = "Conexao ClickUp em um clique sera liberada em breve."
    @ObservationIgnored private static let linearPendingConnectionMessage = "Conexao Linear em um clique sera liberada em breve."
    @ObservationIgnored private static let zapierPendingConnectionMessage = "Automacoes Zapier guiadas serao liberadas em breve."

    init(
        persistence: ActivityPersistence = ActivityPersistence(),
        monitor: ActivityMonitor? = nil,
        googleCalendarPersistence: GoogleCalendarPersistence = GoogleCalendarPersistence(),
        googleCalendarService: GoogleCalendarService = GoogleCalendarService(),
        notionCalendarService: NotionCalendarService = NotionCalendarService(),
        outlookCalendarService: OutlookCalendarService = OutlookCalendarService(),
        clickUpService: ClickUpService = ClickUpService(),
        linearService: LinearService = LinearService(),
        zapierService: ZapierService = ZapierService(),
        monitoringPreferencesPersistence: MonitoringPreferencesPersistence = MonitoringPreferencesPersistence(),
        reminderEngine: ReminderEngine = ReminderEngine(),
        keychainService: KeychainService = KeychainService(),
        cloudSyncService: CloudSyncService = CloudSyncService(),
        workspaceSyncService: WorkspaceSyncService = WorkspaceSyncService(),
        authService: FirebaseAuthService = FirebaseAuthService(),
        aiClassificationService: AIClassificationService = AIClassificationService(),
        weeklyReportEmailService: WeeklyReportEmailService = WeeklyReportEmailService(),
        publicIntegrationConfigService: PublicIntegrationConfigService = PublicIntegrationConfigService(),
        activityPersistenceDebounce: Duration = .seconds(5)
    ) {
        self.persistence = persistence
        self.monitor = monitor ?? ActivityMonitor()
        self.googleCalendarPersistence = googleCalendarPersistence
        self.googleCalendarService = googleCalendarService
        self.notionCalendarService = notionCalendarService
        self.outlookCalendarService = outlookCalendarService
        self.clickUpService = clickUpService
        self.linearService = linearService
        self.zapierService = zapierService
        self.monitoringPreferencesPersistence = monitoringPreferencesPersistence
        self.reminderEngine = reminderEngine
        self.keychainService = keychainService
        self.cloudSyncService = cloudSyncService
        self.workspaceSyncService = workspaceSyncService
        self.authService = authService
        self.aiClassificationService = aiClassificationService
        self.weeklyReportEmailService = weeklyReportEmailService
        self.publicIntegrationConfigService = publicIntegrationConfigService
        self.activityPersistenceDebounce = activityPersistenceDebounce

        let monitoringPreferences = monitoringPreferencesPersistence.load().normalized()
        let calendarSnapshot = googleCalendarPersistence.load()
        let loadedSamples = persistence
            .load(retentionDays: monitoringPreferences.privacySettings.retentionDays)
            .sorted(by: Self.sampleSortOrder)

        self.monitoringPreferences = monitoringPreferences
        self.samples = loadedSamples
        self.googleCalendarClientID = calendarSnapshot.clientID
        self.googleCalendarClientSecret = keychainService.string(for: Self.googleCalendarClientSecretKey) ?? calendarSnapshot.clientSecret
        self.googleCalendarConnections = calendarSnapshot.connections
        self.googleCalendarStatusMessage = googleCalendarConnections.isEmpty ? nil : "Google Agenda pronta para sincronizar."
        let hasStoredNotionToken = keychainService.string(for: Self.notionCalendarTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasStoredOutlookToken = keychainService.string(for: Self.outlookCalendarTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasStoredClickUpToken = keychainService.string(for: Self.clickUpTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasStoredLinearToken = keychainService.string(for: Self.linearTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasStoredZapierWebhook = monitoringPreferences.zapierSettings.webhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        self.notionCalendarStatusMessage = monitoringPreferences.notionCalendarSettings.isEnabled
            ? (hasStoredNotionToken && !monitoringPreferences.notionCalendarSettings.databaseIDs.isEmpty ? "Notion pronto para sincronizar." : Self.notionPendingConnectionMessage)
            : nil
        self.outlookCalendarStatusMessage = monitoringPreferences.outlookCalendarSettings.isEnabled
            ? (hasStoredOutlookToken ? "Outlook pronto para sincronizar." : Self.outlookPendingConnectionMessage)
            : nil
        self.clickUpStatusMessage = monitoringPreferences.clickUpSettings.isEnabled
            ? (hasStoredClickUpToken && !monitoringPreferences.clickUpSettings.listIDs.isEmpty ? "ClickUp pronto para sincronizar." : Self.clickUpPendingConnectionMessage)
            : nil
        self.linearStatusMessage = monitoringPreferences.linearSettings.isEnabled
            ? (hasStoredLinearToken && !monitoringPreferences.linearSettings.teamIDs.isEmpty ? "Linear pronto para sincronizar." : Self.linearPendingConnectionMessage)
            : nil
        self.zapierStatusMessage = monitoringPreferences.zapierSettings.isEnabled
            ? (hasStoredZapierWebhook ? "Zapier pronto para disparar automacoes." : Self.zapierPendingConnectionMessage)
            : nil
        self.cloudSyncStatusMessage = nil
        self.workspaceSyncStatusMessage = nil
        self.aiClassificationStatusMessage = nil
        self.authSession = keychainService.codable(LuumAuthSession.self, for: Self.firebaseAuthSessionKey)
        self.authStatusMessage = self.authSession.map { "Conectado como \($0.accountLabel) • plano \($0.plan.title)" }
        if let pendingRequest = keychainService.codable(LuumAuthRequest.self, for: Self.firebaseAuthRequestKey),
           pendingRequest.isValid() {
            self.pendingAuthRequest = pendingRequest
        } else {
            keychainService.removeValue(for: Self.firebaseAuthRequestKey)
        }

        migrateCalendarSecretsIfNeeded(snapshot: calendarSnapshot)

        self.monitor.onSnapshot = { [weak self] snapshot in
            self?.ingest(snapshot)
        }
        self.monitor.onInactivity = { [weak self] timestamp in
            self?.closeCurrentSession(at: timestamp)
        }
        self.monitor.onAutomationMessage = { [weak self] message in
            self?.updateAutomationStatusMessage(message)
        }
        self.monitor.onInputMonitoringMessage = { [weak self] message in
            self?.updateInputMonitoringMessage(message)
        }

        self.reminderEngine.onPermissionMessage = { [weak self] message, authorized in
            self?.notificationPermissionMessage = message
            self?.notificationsAuthorized = authorized
        }
        self.reminderEngine.onReminderMessage = { [weak self] message in
            self?.lastReminderStatusMessage = message
        }
    }

    var categories: [ActivityCategory] {
        monitoringPreferences.categories
    }

    var defaultCategoryID: String {
        monitoringPreferences.category(for: ActivityCategory.work.id)?.id ??
        monitoringPreferences.category(for: ActivityCategory.uncategorized.id)?.id ??
        monitoringPreferences.categories.first?.id ??
        ActivityCategory.work.id
    }

    var categoryRules: [CategoryRule] {
        monitoringPreferences.categoryRules
    }

    var aiClassificationSettings: AIClassificationSettings {
        monitoringPreferences.aiClassificationSettings
    }

    var hasAIClassificationAPIKey: Bool {
        !(keychainService.string(for: Self.aiClassificationAPIKeyKey)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var secretStorageDescription: String {
        keychainService.storageDescription
    }

    var aiClassificationConfigured: Bool {
        guard aiClassificationSettings.isEnabled else { return false }
        if AIClassificationService.isLuumBackendEndpoint(aiClassificationSettings.endpointURL) {
            return authSession != nil
        }
        return hasAIClassificationAPIKey
    }

    var ignoredApplications: [String] {
        monitoringPreferences.ignoredApplications
    }

    var ignoredDomains: [String] {
        monitoringPreferences.ignoredDomains
    }

    var reminderProfiles: [ReminderProfile] {
        monitoringPreferences.reminderProfiles
    }

    var usageGoals: [UsageGoal] {
        monitoringPreferences.usageGoals
    }

    var focusProfiles: [FocusModeProfile] {
        monitoringPreferences.focusProfiles
    }

    var focusShieldProfilesCount: Int {
        focusProfiles.filter(\.hasBlockingRules).count
    }

    var notionCalendarSettings: NotionCalendarSettings {
        monitoringPreferences.notionCalendarSettings
    }

    var outlookCalendarSettings: OutlookCalendarSettings {
        monitoringPreferences.outlookCalendarSettings
    }

    var clickUpSettings: ClickUpSettings {
        monitoringPreferences.clickUpSettings
    }

    var linearSettings: LinearSettings {
        monitoringPreferences.linearSettings
    }

    var zapierSettings: ZapierSettings {
        monitoringPreferences.zapierSettings
    }

    var teamSettings: TeamSettings {
        monitoringPreferences.teamSettings
    }

    var businessSettings: BusinessWorkspaceSettings {
        monitoringPreferences.businessSettings
    }

    var privacySettings: PrivacySettings {
        monitoringPreferences.privacySettings
    }

    var cloudSyncSettings: CloudSyncSettings {
        monitoringPreferences.cloudSyncSettings
    }

    var rulePreviews: [RulePreview] {
        classifier.previewRules(from: monitoringPreferences)
    }

    var needsOnboarding: Bool {
        !monitoringPreferences.hasCompletedOnboarding
    }


    var isSignedIn: Bool {
        authSession != nil
    }

    var accountPlan: LuumAccountPlan {
        authSession?.plan ?? .trial
    }

    var accountEmail: String {
        authSession?.email ?? ""
    }

    var isAccountLocked: Bool {
        authSession?.isLocked ?? true
    }

    func canUse(_ feature: LuumFeature) -> Bool {
        guard let authSession else { return false }
        return authSession.includes(feature)
    }

    func lockMessage(for feature: LuumFeature) -> String {
        if authSession == nil {
            return "Entre com sua conta Firebase do Luum para liberar o app neste Mac."
        }

        if let explanation = authSession?.lockExplanation {
            return explanation
        }

        return "O recurso \(feature.title) exige um plano maior. Seu plano atual e \(accountPlan.title)."
    }

    func openLoginPage() {
        let request = LuumAuthRequest()
        guard let url = FirebaseAuthService.loginURL(state: request.state) else {
            authStatusMessage = "Nao foi possivel preparar o login do Luum."
            return
        }

        do {
            try keychainService.setCodable(request, for: Self.firebaseAuthRequestKey)
            pendingAuthRequest = request
        } catch {
            authStatusMessage = "Nao foi possivel proteger esta solicitacao de login."
            return
        }

        guard NSWorkspace.shared.open(url) else {
            clearPendingAuthRequest()
            authStatusMessage = "Nao foi possivel abrir o navegador para entrar no Luum."
            return
        }
        authStatusMessage = "Conclua o login no navegador."
    }

    func handleAuthCallbackURL(_ url: URL) {
        let callbackState = FirebaseAuthService.callbackState(from: url)
        guard let pendingAuthRequest, pendingAuthRequest.isValid() else {
            if Self.isDuplicateCompletedAuthCallback(callbackState: callbackState, completedState: lastCompletedAuthState) {
                return
            }
            clearPendingAuthRequest()
            authStatusMessage = "Esta solicitacao de login expirou. Clique em Entrar e tente novamente."
            return
        }

        do {
            let session = try authService.session(from: url, expectedState: pendingAuthRequest.state)
            let callbackSignature = Self.authCallbackSignature(for: session)
            if callbackSignature == lastAuthCallbackSignature,
               isCheckingAuth || authSession?.idToken == session.idToken {
                authStatusMessage = "Login recebido. Validacao ja esta em andamento..."
                return
            }

            lastAuthCallbackSignature = callbackSignature
            lastCompletedAuthState = pendingAuthRequest.state
            clearPendingAuthRequest()
            applyAuthSession(session, message: "Login recebido. Validando plano no Firebase...")
            refreshAccountStatus(restartInFlight: true)
        } catch {
            authStatusMessage = error.localizedDescription
        }
    }

    func refreshAccountStatus() {
        refreshAccountStatus(restartInFlight: false)
    }

    private func refreshAccountStatus(restartInFlight: Bool) {
        guard let authSession else {
            authStatusMessage = "Entre com sua conta Luum para validar o plano."
            return
        }

        if isCheckingAuth {
            guard restartInFlight else { return }
            authRefreshTask?.cancel()
        }

        authRefreshGeneration += 1
        let generation = authRefreshGeneration
        let sessionToValidate = authSession
        isCheckingAuth = true
        authRefreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let verified = try await authService.verifiedSession(
                    sessionToValidate,
                    deviceID: keychainService.installationID()
                )
                let shouldSyncWorkspace = await MainActor.run {
                    guard self.isCurrentAuthRefresh(generation, for: sessionToValidate) else { return false }
                    self.applyAuthSession(verified, message: "Plano \(verified.plan.title) validado.")
                    self.isCheckingAuth = false
                    self.authRefreshTask = nil
                    return self.teamSettings.automaticallySyncWorkspace &&
                        self.teamWorkspaceConfigured
                }
                if shouldSyncWorkspace {
                    self.syncWorkspaceRankingNow()
                }
            } catch {
                let wasCancelled = Task.isCancelled
                await MainActor.run {
                    guard self.isCurrentAuthRefresh(generation, for: sessionToValidate) else { return }
                    if wasCancelled {
                        self.isCheckingAuth = false
                        self.authRefreshTask = nil
                        return
                    }

                    if error is URLError {
                        let offline = sessionToValidate
                        let message = offline.isLocked
                            ? "Conecte-se a internet e valide seu plano para liberar o app."
                            : "Sem conexao com a API. Usando sessao local validada por ate 24 horas."
                        self.applyAuthSession(offline, message: message)
                    } else if Self.isExplicitAuthRejection(error) {
                        self.rejectAuthSession(sessionToValidate)
                    } else {
                        let offline = sessionToValidate
                        let message = offline.isLocked
                            ? "Nao foi possivel validar o plano agora. Tente novamente em instantes."
                            : "A API de assinatura respondeu de forma temporaria. Usando sessao local validada por ate 24 horas."
                        self.applyAuthSession(offline, message: message)
                    }
                    self.isCheckingAuth = false
                    self.authRefreshTask = nil
                }
            }
        }
    }

    func signOut() {
        authRefreshTask?.cancel()
        authRefreshTask = nil
        authRefreshGeneration += 1
        lastAuthCallbackSignature = nil
        lastCompletedAuthState = nil
        clearPendingAuthRequest()
        isCheckingAuth = false
        cloudSyncTask?.cancel()
        cloudSyncTask = nil
        cloudSyncPendingAfterCurrent = false
        workspaceSyncTask?.cancel()
        workspaceSyncTask = nil
        aiClassificationTask?.cancel()
        aiClassificationTask = nil
        weeklyReportEmailTask?.cancel()
        weeklyReportEmailTask = nil
        weeklyReportEmailHealthTask?.cancel()
        weeklyReportEmailHealthTask = nil
        isSyncingCloud = false
        isSyncingWorkspace = false
        isClassifyingWithAI = false
        isSendingWeeklyReportEmail = false
        isCheckingWeeklyReportEmailHealth = false
        stopMonitoring()
        authSession = nil
        authStatusMessage = "Conta desconectada deste Mac."
        keychainService.removeValue(for: Self.firebaseAuthSessionKey)
        keychainService.removeValue(for: Self.teamWorkspaceSecretKey)
        monitoringPreferences.teamSettings.sharesAnonymousMetrics = false
        monitoringPreferences.teamSettings.automaticallySyncWorkspace = false
        monitoringPreferences.teamSettings.workspaceID = ""
        monitoringPreferences.teamSettings.workspaceMemberID = ""
        monitoringPreferences.teamSettings.workspaceEndpointURL = FirebaseAuthService.defaultBaseURL
        workspaceRankingEntries = []
        workspaceSyncLastSyncAt = nil
        workspaceSyncStatusMessage = "Workspace desconectado deste Mac."
        persistMonitoringPreferences()
    }

    private func applyAuthSession(_ session: LuumAuthSession, message: String) {
        persistAuthSession(session, message: message, scheduleCloudSync: true)
    }

    private func persistAuthSession(_ session: LuumAuthSession, message: String, scheduleCloudSync: Bool) {
        authSession = session
        authStatusMessage = message
        do {
            try keychainService.setCodable(session, for: Self.firebaseAuthSessionKey)
        } catch {
            authStatusMessage = error.localizedDescription
        }

        let currentCloudSyncSettings = monitoringPreferences.cloudSyncSettings
        monitoringPreferences.teamSettings.workspaceEndpointURL = FirebaseAuthService.defaultBaseURL
        monitoringPreferences.cloudSyncSettings = Self.cloudSyncSettings(
            currentCloudSyncSettings,
            sanitizedFor: session
        )

        persistMonitoringPreferences()
        if scheduleCloudSync {
            scheduleCloudSyncIfNeeded(reason: "auth-session")
        }

        if canUse(.coreTracking) {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func verifiedAuthSessionForProtectedRequest() async throws -> LuumAuthSession {
        guard let sessionToValidate = authSession else {
            throw FirebaseAuthServiceError.statusRejected("missing_session")
        }

        do {
            let verified = try await authService.verifiedSession(
                sessionToValidate,
                deviceID: keychainService.installationID()
            )
            guard isCurrentAuthSession(sessionToValidate) else { throw CancellationError() }
            persistAuthSession(verified, message: "Plano \(verified.plan.title) validado.", scheduleCloudSync: false)
            return verified
        } catch {
            if Self.isExplicitAuthRejection(error) {
                rejectAuthSession(sessionToValidate)
            }
            throw error
        }
    }

    private static func isExplicitAuthRejection(_ error: Error) -> Bool {
        (error as? FirebaseAuthServiceError)?.isExplicitAuthRejection ?? false
    }

    private func isCurrentAuthRefresh(_ generation: Int, for session: LuumAuthSession) -> Bool {
        guard generation == authRefreshGeneration else { return false }
        return isCurrentAuthSession(session)
    }

    private func isCurrentAuthSession(_ session: LuumAuthSession) -> Bool {
        guard let current = authSession else { return false }
        return current.uid == session.uid && current.idToken == session.idToken
    }

    private func isCurrentVerifiedSession(_ verified: LuumAuthSession) -> Bool {
        guard let current = authSession else { return false }
        return current.uid == verified.uid && current.idToken == verified.idToken
    }

    nonisolated static func authCallbackSignature(for session: LuumAuthSession) -> String {
        "\(session.uid):\(session.idToken.suffix(16))"
    }

    nonisolated static func isDuplicateCompletedAuthCallback(callbackState: String?, completedState: String?) -> Bool {
        guard let callbackState, !callbackState.isEmpty else { return false }
        return callbackState == completedState
    }

    private func clearPendingAuthRequest() {
        pendingAuthRequest = nil
        keychainService.removeValue(for: Self.firebaseAuthRequestKey)
    }

    private func rejectAuthSession(_ session: LuumAuthSession) {
        var rejected = session
        rejected.lockedReason = "auth_validation_failed"
        rejected.lastVerifiedAt = nil
        persistAuthSession(
            rejected,
            message: "A sessao nao foi aceita pela API. Entre novamente para liberar o app.",
            scheduleCloudSync: false
        )
    }

    static func cloudSyncSettings(
        _ settings: CloudSyncSettings,
        sanitizedFor session: LuumAuthSession
    ) -> CloudSyncSettings {
        var sanitized = settings
        let isFirstAccountBinding = sanitized.backupID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sanitized.endpointURL = FirebaseAuthService.defaultBaseURL
        sanitized.backupID = session.uid

        sanitized.isEnabled = session.includes(.cloudBackup) && (sanitized.isEnabled || isFirstAccountBinding)
        if !session.includes(.rawActivityBackup) {
            sanitized.syncRawActivities = false
        }

        return sanitized
    }

    static func isCloudSyncConfigured(
        _ settings: CloudSyncSettings,
        for session: LuumAuthSession?
    ) -> Bool {
        settings.endpointURL == FirebaseAuthService.defaultBaseURL &&
        settings.backupID == session?.uid &&
        !(session?.idToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var onboardingChecklist: [OnboardingChecklistItem] {
        [
            OnboardingChecklistItem(
                id: "monitoring",
                title: "Captura ativa",
                detail: isMonitoring ? "O luum esta capturando apps e sites em background." : "Ative a captura para o luum começar a acompanhar o seu dia.",
                isDone: isMonitoring,
                actionTitle: isMonitoring ? nil : "Iniciar captura"
            ),
            OnboardingChecklistItem(
                id: "google-client",
                title: "Google Calendar pronto",
                detail: isGoogleCalendarConnected ? "Pelo menos uma conta Google ja esta conectada." : "Clique para conectar a agenda com OAuth. O Luum busca a configuracao publica no backend.",
                isDone: isGoogleCalendarConnected,
                actionTitle: isGoogleCalendarConnected ? nil : "Conectar agenda"
            ),
            OnboardingChecklistItem(
                id: "google-account",
                title: "Conta conectada",
                detail: isGoogleCalendarConnected ? "Pelo menos uma conta Google ja esta conectada." : "Conecte uma conta para comparar o planejado com o tempo real.",
                isDone: isGoogleCalendarConnected,
                actionTitle: isGoogleCalendarConnected ? nil : "Conectar conta"
            ),
            OnboardingChecklistItem(
                id: "notifications",
                title: "Notificacoes",
                detail: notificationsAuthorized ? "As notificacoes do luum estao liberadas." : "Permita notificacoes para receber alertas de pausa, foco e distracao.",
                isDone: notificationsAuthorized,
                actionTitle: notificationsAuthorized ? nil : "Permitir notificacoes"
            ),
            OnboardingChecklistItem(
                id: "browser-data",
                title: "Dados do navegador",
                detail: trackedSitesCount > 0 ? "O luum ja conseguiu ler URLs e enriquecer o historico do navegador." : "Abra um navegador suportado e permita Automacao para ler a URL da aba ativa.",
                isDone: trackedSitesCount > 0,
                actionTitle: trackedSitesCount > 0 ? nil : "Abrir automacao"
            ),
        ]
    }

    var trackedAppsCount: Int {
        Set(
            samples.filter { sample in
                !sample.isHidden &&
                    !isIgnored(sample: sample) &&
                    !classifier.isApplicationIgnored(
                        applicationName: sample.applicationName,
                        bundleIdentifier: sample.bundleIdentifier,
                        preferences: monitoringPreferences
                    )
            }
            .map(\.applicationName)
        )
        .count
    }

    var trackedSitesCount: Int {
        Set(samples.filter { !$0.isHidden && !isIgnored(sample: $0) }.compactMap(\.webDomain)).count
    }

    var currentActivityCategory: ActivityCategory? {
        guard let currentSnapshot else { return nil }
        return classifier.classify(
            applicationName: currentSnapshot.applicationName,
            bundleIdentifier: currentSnapshot.bundleIdentifier,
            webURL: sanitizedURL(from: currentSnapshot.webURL),
            preferences: monitoringPreferences
        )
    }

    var currentActivityDuration: TimeInterval {
        guard currentSnapshot != nil else { return 0 }
        guard let lastSample = samples.last else { return 0 }
        return max(Date().timeIntervalSince(lastSample.startDate), lastSample.duration)
    }

    var currentActivityTitle: String {
        guard let currentSnapshot else {
            return "Nenhuma atividade ativa agora"
        }

        if let query = classifier.searchQuery(from: currentSnapshot.webURL) {
            return "\(currentSnapshot.applicationName) • \(query)"
        }

        if let domain = classifier.domain(from: currentSnapshot.webURL) {
            return "\(currentSnapshot.applicationName) em \(domain)"
        }

        return currentSnapshot.applicationName
    }

    var isGoogleCalendarConfigured: Bool {
        !googleCalendarClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            (publicIntegrationConfig?.googleCalendar.configured ?? false)
    }

    var isGoogleCalendarConnected: Bool {
        !googleCalendarConnections.isEmpty
    }

    var googleCalendarAccountLabel: String {
        googleCalendarConnections.first?.profile.name ?? "Google Agenda"
    }

    var googleCalendarIdentityLine: String {
        googleCalendarConnections.first?.profile.email ?? "Conecte sua agenda para cruzar compromissos com o tempo capturado."
    }

    var googleCalendarLastSyncAt: Date? {
        googleCalendarConnections.compactMap(\.lastSyncAt).max()
    }

    var notionCalendarConfigured: Bool {
        hasNotionToken && !notionCalendarSettings.databaseIDs.isEmpty
    }

    var hasNotionToken: Bool {
        !(keychainService.string(for: Self.notionCalendarTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var notionCalendarLastSyncAt: Date? {
        notionCalendarSettings.lastSyncAt
    }

    var outlookCalendarConfigured: Bool {
        hasOutlookToken
    }

    var hasOutlookToken: Bool {
        !(keychainService.string(for: Self.outlookCalendarTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var outlookCalendarLastSyncAt: Date? {
        outlookCalendarSettings.lastSyncAt
    }

    var clickUpConfigured: Bool {
        hasClickUpToken && !clickUpSettings.listIDs.isEmpty
    }

    var hasClickUpToken: Bool {
        !(keychainService.string(for: Self.clickUpTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var clickUpLastSyncAt: Date? {
        clickUpSettings.lastSyncAt
    }

    var linearConfigured: Bool {
        hasLinearToken && !linearSettings.teamIDs.isEmpty
    }

    var hasLinearToken: Bool {
        !(keychainService.string(for: Self.linearTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var linearLastSyncAt: Date? {
        linearSettings.lastSyncAt
    }

    var zapierConfigured: Bool {
        !zapierSettings.webhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var googleCalendarManagedOAuthAvailable: Bool {
        publicIntegrationConfig?.managedOAuth.googleCalendar ?? false
    }

    var notionManagedOAuthAvailable: Bool {
        publicIntegrationConfig?.managedOAuth.notion ?? false
    }

    var outlookManagedOAuthAvailable: Bool {
        publicIntegrationConfig?.managedOAuth.outlookCalendar ?? false
    }

    var clickUpManagedOAuthAvailable: Bool {
        publicIntegrationConfig?.managedOAuth.clickUp ?? false
    }

    var linearManagedOAuthAvailable: Bool {
        publicIntegrationConfig?.managedOAuth.linear ?? false
    }

    var zapierManagedConnectionAvailable: Bool {
        publicIntegrationConfig?.managedOAuth.zapier ?? false
    }

    var teamWorkspaceConfigured: Bool {
        !teamSettings.workspaceEndpointURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !teamSettings.workspaceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !(authSession?.idToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
        !(workspaceSecret?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var hasWorkspaceSecret: Bool {
        !(workspaceSecret?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var cloudSyncConfigured: Bool {
        Self.isCloudSyncConfigured(cloudSyncSettings, for: authSession)
    }

    func bootstrap(selectedDay: Date = Date()) {
        keychainService.removeLegacySystemKeychainItems()
        startMaintenanceLoop()

        if authSession != nil {
            refreshAccountStatus()
        }

        Task { [weak self] in
            await self?.ensureAgenda(for: selectedDay)
            await self?.reminderEngine.refreshAuthorizationStatus()
        }
    }

    func startMonitoring() {
        guard canUse(.coreTracking) else {
            authStatusMessage = lockMessage(for: .coreTracking)
            return
        }
        guard !isMonitoring else { return }
        isMonitoring = true
        monitor.start()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        closeCurrentSession(at: Date())
        monitor.stop()
        flushPersistence()
        isMonitoring = false
    }

    func toggleMonitoring() {
        isMonitoring ? stopMonitoring() : startMonitoring()
    }

    func requestInputMonitoringAccess() {
        monitor.requestInputMonitoringAccess()
    }

    func requestNotificationAuthorization() {
        guard canUse(.reminders) else {
            notificationPermissionMessage = lockMessage(for: .reminders)
            return
        }

        Task { [weak self] in
            await self?.reminderEngine.requestAuthorization()
        }
    }

    func connectGoogleCalendar(for day: Date = Date()) {
        guard !isConnectingGoogleCalendar else { return }

        Task { [weak self] in
            await self?.runCalendarConnect(for: day)
        }
    }

    func refreshPublicIntegrationConfig(force: Bool = false) {
        guard force || publicIntegrationConfig == nil else { return }
        guard !isLoadingPublicIntegrationConfig else { return }

        Task { [weak self] in
            await self?.runPublicIntegrationConfigRefresh()
        }
    }

    func refreshGoogleCalendar(for day: Date = Date()) {
        guard !isConnectingGoogleCalendar, !isSyncingGoogleCalendar else { return }

        Task { [weak self] in
            await self?.runCalendarSync(for: day, force: true)
        }
    }

    func refreshIntegratedCalendars(for day: Date = Date()) {
        if isGoogleCalendarConnected {
            refreshGoogleCalendar(for: day)
        }

        if notionCalendarSettings.isEnabled {
            refreshNotionCalendar(for: day)
        }

        if outlookCalendarSettings.isEnabled {
            refreshOutlookCalendar(for: day)
        }

        if clickUpSettings.isEnabled {
            refreshClickUp(for: day)
        }

        if linearSettings.isEnabled {
            refreshLinear(for: day)
        }
    }

    func disconnectGoogleCalendar(connectionID: String) {
        googleCalendarConnections.removeAll { $0.id == connectionID }
        calendarTokensByConnectionID.removeValue(forKey: connectionID)
        keychainService.removeValue(for: Self.googleCalendarTokenKey(connectionID))
        googleCalendarStatusMessage = googleCalendarConnections.isEmpty ? "Todas as contas Google foram desconectadas." : "Conta removida do luum."
        persistGoogleCalendar()
        scheduleCloudSyncIfNeeded(reason: "calendar-disconnect")
    }

    func setGoogleCalendarConnectionEnabled(_ connectionID: String, isEnabled: Bool) {
        guard let index = googleCalendarConnections.firstIndex(where: { $0.id == connectionID }) else { return }
        googleCalendarConnections[index].isEnabled = isEnabled
        persistGoogleCalendar()
        scheduleCloudSyncIfNeeded(reason: "calendar-toggle")

        guard isEnabled else { return }
        let syncDay = googleCalendarConnections[index].agendaDay ?? Date()
        Task { [weak self] in
            await self?.runCalendarSync(for: syncDay, force: true)
        }
    }

    func setCalendarSelection(connectionID: String, calendarID: String, isSelected: Bool) {
        guard let connectionIndex = googleCalendarConnections.firstIndex(where: { $0.id == connectionID }) else { return }
        guard let calendarIndex = googleCalendarConnections[connectionIndex].calendars.firstIndex(where: { $0.id == calendarID }) else { return }
        googleCalendarConnections[connectionIndex].calendars[calendarIndex].isSelected = isSelected
        googleCalendarConnections[connectionIndex].agendaItems = googleCalendarConnections[connectionIndex].agendaItems.filter { item in
            item.calendarID != calendarID || isSelected
        }
        persistGoogleCalendar()
        scheduleCloudSyncIfNeeded(reason: "calendar-selection")

        guard isSelected else { return }
        let syncDay = googleCalendarConnections[connectionIndex].agendaDay ?? Date()
        Task { [weak self] in
            await self?.runCalendarSync(for: syncDay, force: true)
        }
    }

    func disconnectAllGoogleCalendars() {
        for connection in googleCalendarConnections {
            keychainService.removeValue(for: Self.googleCalendarTokenKey(connection.id))
        }
        googleCalendarConnections = []
        calendarTokensByConnectionID.removeAll()
        googleCalendarStatusMessage = "Google Agenda desconectada deste Mac."
        persistGoogleCalendar()
        scheduleCloudSyncIfNeeded(reason: "calendar-disconnect-all")
    }

    func disconnectGoogleCalendar() {
        disconnectAllGoogleCalendars()
    }

    func updateGoogleCalendarClientID(_ value: String) {
        googleCalendarClientID = value
        persistGoogleCalendar()
    }

    func updateGoogleCalendarClientSecret(_ value: String) {
        googleCalendarClientSecret = value
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.googleCalendarClientSecretKey)
            } else {
                try keychainService.setString(value, for: Self.googleCalendarClientSecretKey)
            }
        } catch {
            googleCalendarStatusMessage = error.localizedDescription
        }
        persistGoogleCalendar()
    }

    func updateNotionCalendarEnabled(_ value: Bool) {
        if value && !canUse(.advancedIntegrations) {
            monitoringPreferences.notionCalendarSettings.isEnabled = false
            notionCalendarStatusMessage = lockMessage(for: .advancedIntegrations)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.notionCalendarSettings.isEnabled = value
        persistMonitoringPreferences()

        guard value else {
            notionAgendaItems = []
            notionAgendaDay = nil
            notionCalendarStatusMessage = "Integracao do Notion pausada."
            return
        }

        notionCalendarStatusMessage = notionCalendarConfigured
            ? "Notion pronto para sincronizar."
            : Self.notionPendingConnectionMessage
    }

    func updateNotionWorkspaceLabel(_ value: String) {
        monitoringPreferences.notionCalendarSettings.workspaceLabel = value
        persistMonitoringPreferences()
    }

    func updateNotionDatePropertyName(_ value: String) {
        monitoringPreferences.notionCalendarSettings.datePropertyName = value
        persistMonitoringPreferences()
    }

    func updateNotionTitlePropertyName(_ value: String) {
        monitoringPreferences.notionCalendarSettings.titlePropertyName = value
        persistMonitoringPreferences()
    }

    func addNotionDataSourceID(_ value: String) {
        guard let normalizedID = NotionCalendarSettings.normalizedDatabaseID(value) else {
            notionCalendarStatusMessage = Self.notionPendingConnectionMessage
            return
        }

        guard !monitoringPreferences.notionCalendarSettings.databaseIDs.contains(normalizedID) else { return }
        monitoringPreferences.notionCalendarSettings.databaseIDs.append(normalizedID)
        monitoringPreferences.notionCalendarSettings.databaseIDs.sort()
        notionCalendarStatusMessage = "Data source adicionada ao Notion."
        persistMonitoringPreferences()
    }

    func removeNotionDataSourceID(_ value: String) {
        monitoringPreferences.notionCalendarSettings.databaseIDs.removeAll { $0 == value }
        if monitoringPreferences.notionCalendarSettings.databaseIDs.isEmpty {
            notionAgendaItems = []
            notionAgendaDay = nil
            notionCalendarStatusMessage = "Nenhuma data source do Notion selecionada."
        }
        persistMonitoringPreferences()
    }

    func updateNotionToken(_ value: String) {
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.notionCalendarTokenKey)
                notionAgendaItems = []
                notionAgendaDay = nil
                notionCalendarStatusMessage = Self.notionPendingConnectionMessage
            } else {
                try keychainService.setString(value, for: Self.notionCalendarTokenKey)
                notionCalendarStatusMessage = "Notion conectado neste Mac."
            }
        } catch {
            notionCalendarStatusMessage = error.localizedDescription
        }
    }

    func refreshNotionCalendar(for day: Date = Date()) {
        guard !isSyncingNotionCalendar else { return }
        Task { [weak self] in
            await self?.runNotionCalendarSync(for: day, force: true)
        }
    }

    func updateOutlookCalendarEnabled(_ value: Bool) {
        if value && !canUse(.agendaIntegrations) {
            monitoringPreferences.outlookCalendarSettings.isEnabled = false
            outlookCalendarStatusMessage = lockMessage(for: .agendaIntegrations)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.outlookCalendarSettings.isEnabled = value
        persistMonitoringPreferences()

        guard value else {
            outlookAgendaItems = []
            outlookAgendaDay = nil
            outlookCalendarStatusMessage = "Integracao do Outlook pausada."
            return
        }

        outlookCalendarStatusMessage = outlookCalendarConfigured
            ? "Outlook pronto para sincronizar."
            : Self.outlookPendingConnectionMessage
    }

    func updateOutlookWorkspaceLabel(_ value: String) {
        monitoringPreferences.outlookCalendarSettings.workspaceLabel = value
        persistMonitoringPreferences()
    }

    func updateOutlookToken(_ value: String) {
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.outlookCalendarTokenKey)
                outlookAgendaItems = []
                outlookAgendaDay = nil
                monitoringPreferences.outlookCalendarSettings.accountEmail = ""
                monitoringPreferences.outlookCalendarSettings.calendars = []
                outlookCalendarStatusMessage = Self.outlookPendingConnectionMessage
            } else {
                try keychainService.setString(value, for: Self.outlookCalendarTokenKey)
                outlookCalendarStatusMessage = "Outlook conectado neste Mac."
            }
            persistMonitoringPreferences()
        } catch {
            outlookCalendarStatusMessage = error.localizedDescription
        }
    }

    func setOutlookCalendarSelection(calendarID: String, isSelected: Bool) {
        guard let index = monitoringPreferences.outlookCalendarSettings.calendars.firstIndex(where: { $0.id == calendarID }) else { return }
        monitoringPreferences.outlookCalendarSettings.calendars[index].isSelected = isSelected
        persistMonitoringPreferences()
    }

    func refreshOutlookCalendar(for day: Date = Date()) {
        guard !isSyncingOutlookCalendar else { return }
        Task { [weak self] in
            await self?.runOutlookCalendarSync(for: day, force: true)
        }
    }

    func updateClickUpEnabled(_ value: Bool) {
        if value && !canUse(.agendaIntegrations) {
            monitoringPreferences.clickUpSettings.isEnabled = false
            clickUpStatusMessage = lockMessage(for: .agendaIntegrations)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.clickUpSettings.isEnabled = value
        persistMonitoringPreferences()

        guard value else {
            clickUpAgendaItems = []
            clickUpAgendaDay = nil
            clickUpStatusMessage = "Integracao do ClickUp pausada."
            return
        }

        clickUpStatusMessage = clickUpConfigured
            ? "ClickUp pronto para sincronizar."
            : Self.clickUpPendingConnectionMessage
    }

    func updateClickUpWorkspaceLabel(_ value: String) {
        monitoringPreferences.clickUpSettings.workspaceLabel = value
        persistMonitoringPreferences()
    }

    func updateClickUpWorkspaceID(_ value: String) {
        monitoringPreferences.clickUpSettings.workspaceID = value
        persistMonitoringPreferences()
    }

    func updateClickUpIncludeClosedTasks(_ value: Bool) {
        monitoringPreferences.clickUpSettings.includeClosedTasks = value
        persistMonitoringPreferences()
    }

    func updateClickUpToken(_ value: String) {
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.clickUpTokenKey)
                clickUpAgendaItems = []
                clickUpAgendaDay = nil
                clickUpStatusMessage = Self.clickUpPendingConnectionMessage
            } else {
                try keychainService.setString(value, for: Self.clickUpTokenKey)
                clickUpStatusMessage = "ClickUp conectado neste Mac."
            }
        } catch {
            clickUpStatusMessage = error.localizedDescription
        }
    }

    func addClickUpListID(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            clickUpStatusMessage = Self.clickUpPendingConnectionMessage
            return
        }

        guard !monitoringPreferences.clickUpSettings.listIDs.contains(normalized) else { return }
        monitoringPreferences.clickUpSettings.listIDs.append(normalized)
        monitoringPreferences.clickUpSettings.listIDs.sort()
        clickUpStatusMessage = "Lista do ClickUp adicionada."
        persistMonitoringPreferences()
    }

    func removeClickUpListID(_ value: String) {
        monitoringPreferences.clickUpSettings.listIDs.removeAll { $0 == value }
        if monitoringPreferences.clickUpSettings.listIDs.isEmpty {
            clickUpAgendaItems = []
            clickUpAgendaDay = nil
            clickUpStatusMessage = "Nenhuma lista do ClickUp selecionada."
        }
        persistMonitoringPreferences()
    }

    func refreshClickUp(for day: Date = Date()) {
        guard !isSyncingClickUp else { return }
        Task { [weak self] in
            await self?.runClickUpSync(for: day, force: true)
        }
    }

    func updateLinearEnabled(_ value: Bool) {
        if value && !canUse(.agendaIntegrations) {
            monitoringPreferences.linearSettings.isEnabled = false
            linearStatusMessage = lockMessage(for: .agendaIntegrations)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.linearSettings.isEnabled = value
        persistMonitoringPreferences()

        guard value else {
            linearAgendaItems = []
            linearAgendaDay = nil
            linearStatusMessage = "Integracao do Linear pausada."
            return
        }

        linearStatusMessage = linearConfigured
            ? "Linear pronto para sincronizar."
            : Self.linearPendingConnectionMessage
    }

    func updateLinearWorkspaceLabel(_ value: String) {
        monitoringPreferences.linearSettings.workspaceLabel = value
        persistMonitoringPreferences()
    }

    func updateLinearWorkspaceID(_ value: String) {
        monitoringPreferences.linearSettings.workspaceID = value
        persistMonitoringPreferences()
    }

    func updateLinearIncludeCompletedIssues(_ value: Bool) {
        monitoringPreferences.linearSettings.includeCompletedIssues = value
        persistMonitoringPreferences()
    }

    func updateLinearToken(_ value: String) {
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.linearTokenKey)
                linearAgendaItems = []
                linearAgendaDay = nil
                linearStatusMessage = Self.linearPendingConnectionMessage
            } else {
                try keychainService.setString(value, for: Self.linearTokenKey)
                linearStatusMessage = "Linear conectado neste Mac."
            }
        } catch {
            linearStatusMessage = error.localizedDescription
        }
    }

    func addLinearTeamID(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            linearStatusMessage = Self.linearPendingConnectionMessage
            return
        }

        guard !monitoringPreferences.linearSettings.teamIDs.contains(normalized) else { return }
        monitoringPreferences.linearSettings.teamIDs.append(normalized)
        monitoringPreferences.linearSettings.teamIDs.sort()
        linearStatusMessage = "Time do Linear adicionado."
        persistMonitoringPreferences()
    }

    func removeLinearTeamID(_ value: String) {
        monitoringPreferences.linearSettings.teamIDs.removeAll { $0 == value }
        if monitoringPreferences.linearSettings.teamIDs.isEmpty {
            linearAgendaItems = []
            linearAgendaDay = nil
            linearStatusMessage = "Nenhum time do Linear selecionado."
        }
        persistMonitoringPreferences()
    }

    func refreshLinear(for day: Date = Date()) {
        guard !isSyncingLinear else { return }
        Task { [weak self] in
            await self?.runLinearSync(for: day, force: true)
        }
    }

    func updateZapierEnabled(_ value: Bool) {
        if value && !canUse(.advancedIntegrations) {
            monitoringPreferences.zapierSettings.isEnabled = false
            zapierStatusMessage = lockMessage(for: .advancedIntegrations)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.zapierSettings.isEnabled = value
        persistMonitoringPreferences()
        zapierStatusMessage = value
            ? (zapierConfigured ? "Zapier pronto para disparar automacoes." : Self.zapierPendingConnectionMessage)
            : "Integracao com Zapier pausada."
    }

    func updateZapierWebhookURL(_ value: String) {
        monitoringPreferences.zapierSettings.webhookURL = value
        persistMonitoringPreferences()
    }

    func updateZapierSendsFocusEvents(_ value: Bool) {
        if value && !canUse(.advancedIntegrations) {
            monitoringPreferences.zapierSettings.sendsFocusEvents = false
            zapierStatusMessage = lockMessage(for: .advancedIntegrations)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.zapierSettings.sendsFocusEvents = value
        persistMonitoringPreferences()
    }

    func updateZapierSendsCalendarSyncEvents(_ value: Bool) {
        if value && !canUse(.advancedIntegrations) {
            monitoringPreferences.zapierSettings.sendsCalendarSyncEvents = false
            zapierStatusMessage = lockMessage(for: .advancedIntegrations)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.zapierSettings.sendsCalendarSyncEvents = value
        persistMonitoringPreferences()
    }

    func updateZapierSendsWorkspaceRankingEvents(_ value: Bool) {
        if value && !canUse(.advancedIntegrations) {
            monitoringPreferences.zapierSettings.sendsWorkspaceRankingEvents = false
            zapierStatusMessage = lockMessage(for: .advancedIntegrations)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.zapierSettings.sendsWorkspaceRankingEvents = value
        persistMonitoringPreferences()
    }

    func sendZapierTestEvent() {
        guard canUse(.advancedIntegrations) else {
            zapierStatusMessage = lockMessage(for: .advancedIntegrations)
            return
        }

        Task { [weak self] in
            await self?.sendZapierEvent(
                type: "manual_test",
                details: [
                    "status": "ok",
                    "source": "luum-settings",
                ]
            )
        }
    }

    func updateAIClassificationEnabled(_ value: Bool) {
        monitoringPreferences.aiClassificationSettings.isEnabled = value
        aiClassificationStatusMessage = value
            ? "IA de classificacao ativada. O Luum usa a configuracao segura da sua conta."
            : "IA de classificacao desativada."
        persistMonitoringPreferences()
    }

    func updateAIClassificationEndpointURL(_ value: String) {
        monitoringPreferences.aiClassificationSettings.endpointURL = value
        persistMonitoringPreferences()
    }

    func updateAIClassificationModel(_ value: String) {
        monitoringPreferences.aiClassificationSettings.model = value
        persistMonitoringPreferences()
    }

    func updateAIClassificationMinimumConfidence(_ value: Double) {
        monitoringPreferences.aiClassificationSettings.minimumConfidence = value
        persistMonitoringPreferences()
    }

    func updateAIClassificationAPIKey(_ value: String) {
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.aiClassificationAPIKeyKey)
                aiClassificationStatusMessage = "Chave da IA removida deste Mac."
            } else {
                try keychainService.setString(value, for: Self.aiClassificationAPIKeyKey)
                aiClassificationStatusMessage = "Chave da IA salva no cofre local cifrado."
            }
        } catch {
            aiClassificationStatusMessage = "Nao foi possivel salvar a chave da IA."
        }
    }

    func classifyApplicationWithAI(_ item: UsageBreakdownItem) {
        aiClassificationTask?.cancel()
        aiClassificationTask = Task { [weak self] in
            await self?.runAIClassification(kind: .application, item: item)
        }
    }

    func classifyDomainWithAI(_ item: UsageBreakdownItem) {
        aiClassificationTask?.cancel()
        aiClassificationTask = Task { [weak self] in
            await self?.runAIClassification(kind: .domain, item: item)
        }
    }

    func updateTeamOrganizationName(_ value: String) {
        monitoringPreferences.teamSettings.organizationName = value
        persistMonitoringPreferences()
    }

    func updateTeamMemberDisplayName(_ value: String) {
        monitoringPreferences.teamSettings.memberDisplayName = value
        persistMonitoringPreferences()
    }

    func updateTeamRoleLabel(_ value: String) {
        monitoringPreferences.teamSettings.roleLabel = value
        persistMonitoringPreferences()
    }

    func updateTeamSharesAnonymousMetrics(_ value: Bool) {
        if value && !canUse(.teamWorkspace) {
            monitoringPreferences.teamSettings.sharesAnonymousMetrics = false
            workspaceSyncStatusMessage = lockMessage(for: .teamWorkspace)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.teamSettings.sharesAnonymousMetrics = value
        persistMonitoringPreferences()
    }

    func updateTeamWorkspaceID(_ value: String) {
        monitoringPreferences.teamSettings.workspaceID = value
        persistMonitoringPreferences()
    }

    func updateTeamWorkspaceMemberID(_ value: String) {
        monitoringPreferences.teamSettings.workspaceMemberID = value
        persistMonitoringPreferences()
    }

    func updateTeamWorkspaceEndpointURL(_ value: String) {
        monitoringPreferences.teamSettings.workspaceEndpointURL = FirebaseAuthService.defaultBaseURL
        persistMonitoringPreferences()
    }

    func updateTeamAutomaticallySyncWorkspace(_ value: Bool) {
        if value && !canUse(.teamWorkspace) {
            monitoringPreferences.teamSettings.automaticallySyncWorkspace = false
            workspaceSyncStatusMessage = lockMessage(for: .teamWorkspace)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.teamSettings.automaticallySyncWorkspace = value
        persistMonitoringPreferences()
    }

    func updateTeamWorkspaceSecret(_ value: String) {
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.teamWorkspaceSecretKey)
                workspaceSyncStatusMessage = "Chave do workspace removida deste Mac."
            } else {
                try keychainService.setString(value, for: Self.teamWorkspaceSecretKey)
                workspaceSyncStatusMessage = "Chave do workspace atualizada neste Mac."
            }
        } catch {
            workspaceSyncStatusMessage = error.localizedDescription
        }
    }

    func syncWorkspaceRankingNow(for day: Date = Date()) {
        guard !isSyncingWorkspace else { return }
        workspaceSyncTask?.cancel()
        workspaceSyncTask = Task { [weak self] in
            await self?.runWorkspaceSync(for: day, force: true)
        }
    }

    func addBusinessClient(name: String, domain: String = "") {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        monitoringPreferences.businessSettings.clients.append(
            WorkClientProfile(name: cleanName, domain: domain)
        )
        persistMonitoringPreferences()
    }

    func updateBusinessClient(_ client: WorkClientProfile) {
        guard let index = monitoringPreferences.businessSettings.clients.firstIndex(where: { $0.id == client.id }) else { return }
        monitoringPreferences.businessSettings.clients[index] = client
        persistMonitoringPreferences()
    }

    func removeBusinessClient(id: UUID) {
        monitoringPreferences.businessSettings.clients.removeAll { $0.id == id }
        monitoringPreferences.businessSettings.projects.removeAll { $0.clientID == id }
        persistMonitoringPreferences()
    }

    func addBusinessProject(clientID: UUID, title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty,
              monitoringPreferences.businessSettings.clients.contains(where: { $0.id == clientID })
        else { return }

        monitoringPreferences.businessSettings.projects.append(
            WorkProjectProfile(clientID: clientID, title: cleanTitle)
        )
        persistMonitoringPreferences()
    }

    func updateBusinessProject(_ project: WorkProjectProfile) {
        guard monitoringPreferences.businessSettings.clients.contains(where: { $0.id == project.clientID }),
              let index = monitoringPreferences.businessSettings.projects.firstIndex(where: { $0.id == project.id })
        else { return }

        monitoringPreferences.businessSettings.projects[index] = project
        persistMonitoringPreferences()
    }

    func removeBusinessProject(id: UUID) {
        monitoringPreferences.businessSettings.projects.removeAll { $0.id == id }
        persistMonitoringPreferences()
    }

    func addBusinessTask(projectID: UUID, title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty,
              let index = monitoringPreferences.businessSettings.projects.firstIndex(where: { $0.id == projectID })
        else { return }

        monitoringPreferences.businessSettings.projects[index].tasks.append(
            WorkTaskProfile(title: cleanTitle)
        )
        persistMonitoringPreferences()
    }

    func removeBusinessTask(projectID: UUID, taskID: UUID) {
        guard let index = monitoringPreferences.businessSettings.projects.firstIndex(where: { $0.id == projectID }) else { return }
        monitoringPreferences.businessSettings.projects[index].tasks.removeAll { $0.id == taskID }
        persistMonitoringPreferences()
    }

    func updatePrivacyStorePageTitles(_ value: Bool) {
        monitoringPreferences.privacySettings.storesPageTitles = value
        persistMonitoringPreferences()
    }

    func updatePrivacyStoreFullURLs(_ value: Bool) {
        monitoringPreferences.privacySettings.storesFullURLs = value
        persistMonitoringPreferences()
    }

    func updatePrivacyRetentionDays(_ value: Int) {
        monitoringPreferences.privacySettings.retentionDays = value
        samples = persistence.trim(samples: samples, retentionDays: monitoringPreferences.privacySettings.retentionDays)
        persistMonitoringPreferences()
        schedulePersistence()
    }

    func updatePrivacySyncOnlyDomains(_ value: Bool) {
        monitoringPreferences.privacySettings.syncOnlyDomains = value
        persistMonitoringPreferences()
    }

    func updateCloudSyncEnabled(_ value: Bool) {
        if value && !canUse(.cloudBackup) {
            monitoringPreferences.cloudSyncSettings.isEnabled = false
            cloudSyncStatusMessage = lockMessage(for: .cloudBackup)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.cloudSyncSettings.isEnabled = value
        persistMonitoringPreferences()
        if value {
            scheduleCloudSyncIfNeeded(reason: "cloud-enabled")
        } else {
            cloudSyncTask?.cancel()
            cloudSyncTask = nil
            cloudSyncPendingAfterCurrent = false
        }
    }

    func updateCloudSyncEndpointURL(_ value: String) {
        monitoringPreferences.cloudSyncSettings.endpointURL = FirebaseAuthService.defaultBaseURL
        persistMonitoringPreferences()
    }

    func updateCloudSyncBackupID(_ value: String) {
        monitoringPreferences.cloudSyncSettings.backupID = authSession?.uid ?? ""
        persistMonitoringPreferences()
    }

    func updateCloudSyncSyncRawActivities(_ value: Bool) {
        if value && !canUse(.rawActivityBackup) {
            monitoringPreferences.cloudSyncSettings.syncRawActivities = false
            cloudSyncStatusMessage = lockMessage(for: .rawActivityBackup)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.cloudSyncSettings.syncRawActivities = value
        persistMonitoringPreferences()
    }

    func updateCloudSyncSyncDailySummaries(_ value: Bool) {
        monitoringPreferences.cloudSyncSettings.syncDailySummaries = value
        persistMonitoringPreferences()
    }

    func updateCloudSyncSyncCategories(_ value: Bool) {
        monitoringPreferences.cloudSyncSettings.syncCategoriesAndRules = value
        persistMonitoringPreferences()
    }

    func syncCloudBackupNow() {
        guard !isSyncingCloud else { return }
        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            await self?.runCloudSync()
        }
    }

    func restoreCloudBackup() {
        guard !isSyncingCloud else { return }
        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            await self?.runCloudRestore()
        }
    }

    func category(for id: String) -> ActivityCategory? {
        monitoringPreferences.category(for: id)
    }

    func completeOnboarding() {
        monitoringPreferences.hasCompletedOnboarding = true
        persistMonitoringPreferences()
    }

    func reopenOnboarding() {
        monitoringPreferences.hasCompletedOnboarding = false
        persistMonitoringPreferences()
    }

    func addUsageGoal(
        title: String,
        categoryID: String,
        targetMinutes: Int,
        period: GoalPeriod,
        direction: GoalDirection
    ) {
        guard canUse(.focusModes) else {
            focusModeStatusMessage = lockMessage(for: .focusModes)
            return
        }

        guard monitoringPreferences.category(for: categoryID) != nil else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        monitoringPreferences.usageGoals.append(
            UsageGoal(
                title: trimmedTitle.isEmpty ? "Meta" : trimmedTitle,
                categoryID: categoryID,
                targetMinutes: max(5, targetMinutes),
                period: period,
                direction: direction,
                isEnabled: true
            )
        )
        persistMonitoringPreferences()
    }

    func updateUsageGoal(_ goal: UsageGoal) {
        guard canUse(.focusModes) else {
            focusModeStatusMessage = lockMessage(for: .focusModes)
            return
        }

        guard let index = monitoringPreferences.usageGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        guard monitoringPreferences.category(for: goal.categoryID) != nil else { return }
        var normalizedGoal = goal
        normalizedGoal.title = normalizedGoal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Meta" : normalizedGoal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedGoal.targetMinutes = max(5, normalizedGoal.targetMinutes)
        monitoringPreferences.usageGoals[index] = normalizedGoal
        persistMonitoringPreferences()
    }

    func removeUsageGoal(id: UUID) {
        monitoringPreferences.usageGoals.removeAll { $0.id == id }
        persistMonitoringPreferences()
    }

    func addFocusProfile(
        title: String,
        kind: FocusModeKind,
        categoryIDs: [String],
        thresholdMinutes: Int,
        weekdays: [Int],
        startHour: Int,
        endHour: Int,
        message: String,
        blockedApplications: [String] = [],
        blockedDomains: [String] = []
    ) {
        guard canUse(.focusModes) else {
            focusModeStatusMessage = lockMessage(for: .focusModes)
            return
        }

        let validCategoryIDs = Array(Set(categoryIDs.filter { monitoringPreferences.category(for: $0) != nil })).sorted()
        let validWeekdays = Array(Set(weekdays.filter { (1 ... 7).contains($0) })).sorted()
        guard !validCategoryIDs.isEmpty, !validWeekdays.isEmpty else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        monitoringPreferences.focusProfiles.append(
            FocusModeProfile(
                title: trimmedTitle.isEmpty ? "Modo \(kind.title.lowercased())" : trimmedTitle,
                kind: kind,
                categoryIDs: validCategoryIDs,
                thresholdMinutes: max(5, thresholdMinutes),
                weekdays: validWeekdays,
                startHour: min(max(startHour, 0), 23),
                endHour: min(max(endHour, 1), 24),
                isEnabled: true,
                message: trimmedMessage.isEmpty ? "O luum detectou uma sequencia longa dentro desse perfil." : trimmedMessage,
                blockedApplications: blockedApplications,
                blockedDomains: blockedDomains
            )
        )
        persistMonitoringPreferences()
    }

    func updateFocusProfile(_ profile: FocusModeProfile) {
        guard canUse(.focusModes) else {
            focusModeStatusMessage = lockMessage(for: .focusModes)
            return
        }

        guard let index = monitoringPreferences.focusProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        monitoringPreferences.focusProfiles[index] = profile
        persistMonitoringPreferences()
    }

    func removeFocusProfile(id: UUID) {
        monitoringPreferences.focusProfiles.removeAll { $0.id == id }
        persistMonitoringPreferences()
    }

    func addCategory(title: String, systemImage: String, colorToken: CategoryColorToken) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let slug = slugify(trimmedTitle)
        let uniqueID = uniqueCategoryID(base: slug)

        monitoringPreferences.categories.append(
            ActivityCategory(
                id: uniqueID,
                title: trimmedTitle,
                systemImage: systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "tag.fill" : systemImage,
                colorToken: colorToken,
                isBuiltIn: false
            )
        )
        persistMonitoringPreferences()
    }

    func updateCategoryTitle(id: String, title: String) {
        guard let index = monitoringPreferences.categories.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        monitoringPreferences.categories[index].title = trimmed
        persistMonitoringPreferences()
    }

    func updateCategorySymbol(id: String, systemImage: String) {
        guard let index = monitoringPreferences.categories.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = systemImage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        monitoringPreferences.categories[index].systemImage = trimmed
        persistMonitoringPreferences()
    }

    func updateCategoryColor(id: String, colorToken: CategoryColorToken) {
        guard let index = monitoringPreferences.categories.firstIndex(where: { $0.id == id }) else { return }
        monitoringPreferences.categories[index].colorToken = colorToken
        persistMonitoringPreferences()
    }

    func removeCategory(id: String) {
        guard let category = monitoringPreferences.category(for: id), !category.isBuiltIn else { return }
        monitoringPreferences.categories.removeAll { $0.id == id }
        monitoringPreferences.categoryRules.removeAll { $0.categoryID == id }
        monitoringPreferences.reminderProfiles.removeAll { $0.categoryID == id }
        monitoringPreferences.usageGoals.removeAll { $0.categoryID == id }
        monitoringPreferences.focusProfiles = monitoringPreferences.focusProfiles.compactMap { profile in
            var updatedProfile = profile
            updatedProfile.categoryIDs.removeAll { $0 == id }
            return updatedProfile.categoryIDs.isEmpty ? nil : updatedProfile
        }
        for index in samples.indices where samples[index].manualCategoryID == id {
            samples[index].manualCategoryID = nil
        }
        persistMonitoringPreferences()
        schedulePersistence()
    }

    func assignCategory(toApplication applicationName: String, categoryID: String) {
        upsertRule(
            categoryID: categoryID,
            matchTarget: .applicationName,
            pattern: applicationName
        )
    }

    func assignCategory(toDomain domain: String, categoryID: String) {
        upsertRule(
            categoryID: categoryID,
            matchTarget: .domain,
            pattern: domain
        )
    }

    func addRule(categoryID: String, matchTarget: RuleMatchTarget, pattern: String) {
        upsertRule(categoryID: categoryID, matchTarget: matchTarget, pattern: pattern)
    }

    func updateRule(_ rule: CategoryRule) {
        guard let index = monitoringPreferences.categoryRules.firstIndex(where: { $0.id == rule.id }) else { return }
        var updatedRule = rule
        updatedRule.pattern = normalizePattern(rule.pattern, for: rule.matchTarget)
        guard !updatedRule.pattern.isEmpty else { return }
        monitoringPreferences.categoryRules[index] = updatedRule
        persistMonitoringPreferences()
    }

    func removeRule(id: UUID) {
        monitoringPreferences.categoryRules.removeAll { $0.id == id }
        persistMonitoringPreferences()
    }

    func addIgnoredApplication(_ pattern: String) {
        let cleanedPattern = normalizePattern(pattern)
        guard !cleanedPattern.isEmpty else { return }
        guard !monitoringPreferences.ignoredApplications.contains(cleanedPattern) else { return }
        monitoringPreferences.ignoredApplications.append(cleanedPattern)
        persistMonitoringPreferences()
    }

    func removeIgnoredApplication(_ pattern: String) {
        monitoringPreferences.ignoredApplications.removeAll { $0 == pattern }
        persistMonitoringPreferences()
    }

    func addIgnoredDomain(_ pattern: String) {
        let cleanedPattern = normalizePattern(pattern, for: .domain)
        guard !cleanedPattern.isEmpty else { return }
        guard !monitoringPreferences.ignoredDomains.contains(cleanedPattern) else { return }
        monitoringPreferences.ignoredDomains.append(cleanedPattern)
        persistMonitoringPreferences()
    }

    func removeIgnoredDomain(_ pattern: String) {
        monitoringPreferences.ignoredDomains.removeAll { $0 == pattern }
        persistMonitoringPreferences()
    }

    func addReminder(
        title: String,
        categoryID: String,
        thresholdMinutes: Int,
        weekdays: [Int],
        message: String
    ) {
        guard canUse(.reminders) else {
            lastReminderStatusMessage = lockMessage(for: .reminders)
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard monitoringPreferences.category(for: categoryID) != nil else { return }
        let normalizedWeekdays = Array(Set(weekdays.filter { (1 ... 7).contains($0) })).sorted()
        guard !normalizedWeekdays.isEmpty else { return }

        monitoringPreferences.reminderProfiles.append(
            ReminderProfile(
                title: trimmedTitle,
                categoryID: categoryID,
                thresholdMinutes: max(5, thresholdMinutes),
                weekdays: normalizedWeekdays,
                isEnabled: true,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "O luum percebeu uma sequencia longa dessa categoria."
                    : message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        persistMonitoringPreferences()
    }

    func updateReminder(_ reminder: ReminderProfile) {
        guard canUse(.reminders) else {
            lastReminderStatusMessage = lockMessage(for: .reminders)
            return
        }

        guard let index = monitoringPreferences.reminderProfiles.firstIndex(where: { $0.id == reminder.id }) else { return }
        guard monitoringPreferences.category(for: reminder.categoryID) != nil else { return }

        var normalizedReminder = reminder
        normalizedReminder.title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Lembrete"
            : reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedReminder.message = reminder.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "O luum percebeu uma sequencia longa dessa categoria."
            : reminder.message.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedReminder.thresholdMinutes = max(5, reminder.thresholdMinutes)
        normalizedReminder.weekdays = Array(Set(reminder.weekdays.filter { (1 ... 7).contains($0) })).sorted()
        guard !normalizedReminder.weekdays.isEmpty else { return }

        monitoringPreferences.reminderProfiles[index] = normalizedReminder
        persistMonitoringPreferences()
    }

    func removeReminder(id: UUID) {
        monitoringPreferences.reminderProfiles.removeAll { $0.id == id }
        persistMonitoringPreferences()
    }

    func overrideActivityCategory(sampleID: UUID, categoryID: String?) {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return }
        if let categoryID, monitoringPreferences.category(for: categoryID) == nil {
            return
        }
        let affectedSample = samples[index]
        samples[index].manualCategoryID = categoryID
        invalidateSummaries(touching: affectedSample)
        schedulePersistence()
        evaluateReminders()
    }

    func setActivityHidden(sampleID: UUID, isHidden: Bool) {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return }
        let affectedSample = samples[index]
        samples[index].isHidden = isHidden
        invalidateSummaries(touching: affectedSample)
        schedulePersistence()
        evaluateReminders()
    }

    func resetActivityEdits(sampleID: UUID) {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return }
        let affectedSample = samples[index]
        samples[index].manualCategoryID = nil
        samples[index].isHidden = false
        samples[index].note = nil
        invalidateSummaries(touching: affectedSample)
        schedulePersistence()
        evaluateReminders()
    }

    func updateActivityNote(sampleID: UUID, note: String) {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return }
        let affectedSample = samples[index]
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        samples[index].note = trimmedNote.isEmpty ? nil : trimmedNote
        invalidateSummaries(touching: affectedSample)
        schedulePersistence()
    }

    func overrideCurrentActivityCategory(categoryID: String) {
        guard let lastSample = samples.last else { return }
        overrideActivityCategory(sampleID: lastSample.id, categoryID: categoryID)
    }

    func splitActivity(sampleID: UUID, at splitDate: Date) {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return }
        let sample = samples[index]
        guard splitDate > sample.startDate.addingTimeInterval(60) else { return }
        guard splitDate < sample.endDate.addingTimeInterval(-60) else { return }

        var firstPart = sample
        firstPart.endDate = splitDate

        let secondPart = ActivitySample(
            startDate: splitDate,
            endDate: sample.endDate,
            applicationName: sample.applicationName,
            bundleIdentifier: sample.bundleIdentifier,
            webURL: sample.webURL,
            webDomain: sample.webDomain,
            pageTitle: sample.pageTitle,
            source: sample.source,
            manualCategoryID: sample.manualCategoryID,
            isHidden: sample.isHidden,
            note: sample.note
        )

        samples[index] = firstPart
        samples.insert(secondPart, at: index + 1)
        sortSamples()
        invalidateSummaries(touching: sample)
        schedulePersistence()
        evaluateReminders()
    }

    func mergeActivity(sampleID: UUID, direction: TimelineMergeDirection) {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return }
        let otherIndex = direction == .previous ? index - 1 : index + 1
        guard samples.indices.contains(otherIndex) else { return }

        let current = samples[index]
        let adjacent = samples[otherIndex]
        guard canMerge(lhs: current, rhs: adjacent) else { return }

        var merged = current
        merged.startDate = min(current.startDate, adjacent.startDate)
        merged.endDate = max(current.endDate, adjacent.endDate)
        merged.manualCategoryID = current.manualCategoryID ?? adjacent.manualCategoryID
        merged.isHidden = current.isHidden || adjacent.isHidden
        merged.note = [adjacent.note, current.note].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n")
            .nilIfBlank

        let lowerIndex = min(index, otherIndex)
        let higherIndex = max(index, otherIndex)
        samples.remove(at: higherIndex)
        samples[lowerIndex] = merged
        sortSamples()
        invalidateSummaries(from: min(current.startDate, adjacent.startDate), to: max(current.endDate, adjacent.endDate))
        schedulePersistence()
        evaluateReminders()
    }

    func canMergeActivity(sampleID: UUID, direction: TimelineMergeDirection) -> Bool {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return false }
        let otherIndex = direction == .previous ? index - 1 : index + 1
        guard samples.indices.contains(otherIndex) else { return false }
        return canMerge(lhs: samples[index], rhs: samples[otherIndex])
    }

    func ensureAgenda(for day: Date) async {
        await runCalendarSync(for: day, force: false)
        await runNotionCalendarSync(for: day, force: false)
        await runOutlookCalendarSync(for: day, force: false)
        await runClickUpSync(for: day, force: false)
        await runLinearSync(for: day, force: false)
    }

    func agendaSummary(for day: Date) -> AgendaSummary {
        let calendar = Calendar.autoupdatingCurrent
        let normalizedDay = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: normalizedDay) ?? normalizedDay.addingTimeInterval(86_400)
        let agendaWindowEnd = calendar.date(byAdding: .day, value: 4, to: normalizedDay) ?? dayEnd
        let enabledConnections = googleCalendarConnections.filter(\.isEnabled)
        let googleEvents: [CalendarAgendaItem] = enabledConnections.flatMap { connection in
            let storedDay = connection.agendaDay.map { Calendar.autoupdatingCurrent.startOfDay(for: $0) }
            guard storedDay == normalizedDay else { return [CalendarAgendaItem]() }
            return connection.agendaItems.filter { event in
                event.endDate > normalizedDay && event.startDate < agendaWindowEnd
            }
        }
        let notionEvents: [CalendarAgendaItem]
        if notionCalendarSettings.isEnabled,
           notionAgendaDay == normalizedDay {
            notionEvents = notionAgendaItems.filter { event in
                event.endDate > normalizedDay && event.startDate < agendaWindowEnd
            }
        } else {
            notionEvents = []
        }

        let outlookEvents: [CalendarAgendaItem]
        if outlookCalendarSettings.isEnabled,
           outlookAgendaDay == normalizedDay {
            outlookEvents = outlookAgendaItems.filter { event in
                event.endDate > normalizedDay && event.startDate < agendaWindowEnd
            }
        } else {
            outlookEvents = []
        }

        let clickUpEvents: [CalendarAgendaItem]
        if clickUpSettings.isEnabled,
           clickUpAgendaDay == normalizedDay {
            clickUpEvents = clickUpAgendaItems.filter { event in
                event.endDate > normalizedDay && event.startDate < agendaWindowEnd
            }
        } else {
            clickUpEvents = []
        }

        let linearEvents: [CalendarAgendaItem]
        if linearSettings.isEnabled,
           linearAgendaDay == normalizedDay {
            linearEvents = linearAgendaItems.filter { event in
                event.endDate > normalizedDay && event.startDate < agendaWindowEnd
            }
        } else {
            linearEvents = []
        }

        let events = (googleEvents + notionEvents + outlookEvents + clickUpEvents + linearEvents)
            .sorted(by: { $0.startDate < $1.startDate })
        let focusedEvents = events.filter { event in
            event.endDate > normalizedDay && event.startDate < dayEnd
        }

        let lastSyncAt = (
            enabledConnections.compactMap(\.lastSyncAt)
                + [
                    notionCalendarSettings.lastSyncAt,
                    outlookCalendarSettings.lastSyncAt,
                    clickUpSettings.lastSyncAt,
                    linearSettings.lastSyncAt,
                ].compactMap { $0 }
        ).max()

        return AgendaSummary(
            day: day,
            events: events,
            focusedEvents: focusedEvents,
            isConnected: !enabledConnections.isEmpty
                || (notionCalendarSettings.isEnabled && notionCalendarConfigured)
                || (outlookCalendarSettings.isEnabled && outlookCalendarConfigured)
                || (clickUpSettings.isEnabled && clickUpConfigured)
                || (linearSettings.isEnabled && linearConfigured),
            isConfigured: isGoogleCalendarConfigured || notionCalendarConfigured || outlookCalendarConfigured || clickUpConfigured || linearConfigured,
            lastSyncAt: lastSyncAt,
            connections: enabledConnections.map {
                GoogleCalendarConnectionSummary(
                    id: $0.id,
                    profile: $0.profile,
                    calendars: $0.calendars,
                    isEnabled: $0.isEnabled,
                    lastSyncAt: $0.lastSyncAt
                )
            },
            notionSources: notionCalendarSettings.isEnabled && notionCalendarConfigured
                ? [
                    NotionCalendarSourceSummary(
                        id: "notion-\(slugify(notionCalendarSettings.workspaceLabel))",
                        workspaceLabel: notionCalendarSettings.workspaceLabel,
                        dataSourceIDs: notionCalendarSettings.databaseIDs,
                        lastSyncAt: notionCalendarSettings.lastSyncAt
                    ),
                ]
                : [],
            outlookSources: outlookCalendarSettings.isEnabled && outlookCalendarConfigured
                ? [
                    OutlookCalendarSourceSummary(
                        id: "outlook-\(slugify(outlookCalendarSettings.workspaceLabel))",
                        workspaceLabel: outlookCalendarSettings.workspaceLabel,
                        accountEmail: outlookCalendarSettings.accountEmail,
                        calendars: outlookCalendarSettings.calendars,
                        lastSyncAt: outlookCalendarSettings.lastSyncAt
                    ),
                ]
                : [],
            clickUpSources: clickUpSettings.isEnabled && clickUpConfigured
                ? [
                    WorkItemSourceSummary(
                        id: "clickup-\(slugify(clickUpSettings.workspaceLabel))",
                        title: clickUpSettings.workspaceLabel,
                        configuredSourceIDs: clickUpSettings.listIDs,
                        itemCount: clickUpEvents.count,
                        lastSyncAt: clickUpSettings.lastSyncAt
                    ),
                ]
                : [],
            linearSources: linearSettings.isEnabled && linearConfigured
                ? [
                    WorkItemSourceSummary(
                        id: "linear-\(slugify(linearSettings.workspaceLabel))",
                        title: linearSettings.workspaceLabel,
                        configuredSourceIDs: linearSettings.teamIDs,
                        itemCount: linearEvents.count,
                        lastSyncAt: linearSettings.lastSyncAt
                    ),
                ]
                : []
        )
    }

    func summary(for day: Date) -> DailySummary {
        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        if let cached = summaryCache[normalizedDay] {
            return cached
        }

        let calendar = Calendar.autoupdatingCurrent
        let dayStart = normalizedDay
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        // Binary search for first sample with startDate >= dayStart - tolerance.
        // Samples are sorted ascending by startDate. This skips older days in O(log N).
        let searchStart = dayStart.addingTimeInterval(-sessionGapTolerance)
        var lo = 0, hi = samples.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if samples[mid].startDate < searchStart { lo = mid + 1 } else { hi = mid }
        }
        // Walk backward to pick up any sample that started before searchStart but
        // whose endDate still overlaps this day (e.g. a session open since yesterday).
        while lo > 0 && samples[lo - 1].endDate > dayStart { lo -= 1 }

        var categoryTotals: [ActivityCategory: TimeInterval] = [:]
        var appBuckets: [String: AggregateBucket] = [:]
        var websiteBuckets: [String: AggregateBucket] = [:]
        var resolvedActivities: [ResolvedActivitySample] = []

        for sample in samples[lo...] {
            guard !sample.isHidden else { continue }
            if sample.startDate >= dayEnd { break }
            guard sampleOverlaps(sample, from: dayStart, to: dayEnd) else { continue }
            guard let clipped = clip(sample: sample, from: dayStart, to: dayEnd) else { continue }
            guard !isIgnored(sample: clipped) else { continue }

            let category = classifier.classify(sample: clipped, preferences: monitoringPreferences)
            let applicationIgnored = classifier.isApplicationIgnored(
                applicationName: clipped.applicationName,
                bundleIdentifier: clipped.bundleIdentifier,
                preferences: monitoringPreferences
            )
            categoryTotals[category, default: 0] += clipped.duration

            if !applicationIgnored {
                var appBucket = appBuckets[clipped.applicationName, default: AggregateBucket(
                    label: clipped.applicationName,
                    secondaryLabel: clipped.bundleIdentifier,
                    systemImage: "app.connected.to.app.below.fill"
                )]
                appBucket.duration += clipped.duration
                appBucket.categoryTotals[category, default: 0] += clipped.duration
                appBuckets[clipped.applicationName] = appBucket
            }

            if let domain = clipped.webDomain {
                var websiteBucket = websiteBuckets[domain, default: AggregateBucket(
                    label: domain,
                    secondaryLabel: clipped.applicationName,
                    systemImage: "globe"
                )]
                websiteBucket.duration += clipped.duration
                websiteBucket.categoryTotals[category, default: 0] += clipped.duration
                websiteBuckets[domain] = websiteBucket
            }

            resolvedActivities.append(ResolvedActivitySample(sample: clipped, category: category))
        }

        let categoryBreakdown = categoryTotals
            .map { CategoryBreakdown(category: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }

        let appBreakdown = appBuckets.values
            .map(\.item)
            .sorted { $0.duration > $1.duration }

        let websiteBreakdown = websiteBuckets.values
            .map(\.item)
            .sorted { $0.duration > $1.duration }

        let timelineActivities = resolvedActivities
            .sorted { $0.startDate > $1.startDate }

        let recentActivities = resolvedActivities
            .sorted { $0.endDate > $1.endDate }
            .prefix(20)
            .map { $0 }

        let totalTrackedTime = categoryTotals.values.reduce(0, +)

        let summary = DailySummary(
            day: day,
            totalTrackedTime: totalTrackedTime,
            categoryBreakdown: categoryBreakdown,
            appBreakdown: appBreakdown,
            websiteBreakdown: websiteBreakdown,
            timelineActivities: timelineActivities,
            recentActivities: recentActivities
        )

        summaryCache[normalizedDay] = summary
        return summary
    }

    func goalProgress(for day: Date) -> [GoalProgress] {
        let summary = summary(for: day)
        let categoryTotals = Dictionary(uniqueKeysWithValues: summary.categoryBreakdown.map { ($0.category.id, $0.duration) })

        return usageGoals
            .filter { $0.isEnabled && $0.period == .daily }
            .compactMap { goal in
                guard let category = category(for: goal.categoryID) else { return nil }
                return GoalProgress(
                    goal: goal,
                    category: category,
                    currentDuration: categoryTotals[goal.categoryID] ?? 0
                )
            }
            .sorted { $0.goal.title < $1.goal.title }
    }

    func focusProfileInsights(at date: Date = Date()) -> [FocusProfileInsight] {
        let orderedSamples = visibleSamplesForCurrentStreak()

        return focusProfiles.compactMap { profile in
            let categories = profile.categoryIDs.compactMap { category(for: $0) }
            guard !categories.isEmpty else { return nil }

            let isWithinSchedule = isProfileWithinSchedule(profile, at: date)
            let duration = continuousStreakDuration(for: Set(profile.categoryIDs), in: orderedSamples)

            return FocusProfileInsight(
                profile: profile,
                categories: categories,
                currentDuration: duration,
                isWithinSchedule: isWithinSchedule
            )
        }
        .sorted {
            if $0.isTriggered == $1.isTriggered {
                return $0.currentDuration > $1.currentDuration
            }

            return $0.isTriggered && !$1.isTriggered
        }
    }

    var classificationSuggestions: [ClassificationSuggestion] {
        struct SuggestionAccumulator {
            let kind: SuggestionTargetKind
            let pattern: String
            let categoryID: String
            var sampleCount: Int = 0
            var totalDuration: TimeInterval = 0
        }

        let existingAppRules = Set(categoryRules.filter { $0.matchTarget == .applicationName }.map(\.pattern))
        let existingDomainRules = Set(categoryRules.filter { $0.matchTarget == .domain }.map(\.pattern))
        var accumulators: [String: SuggestionAccumulator] = [:]

        for sample in samples where !sample.isHidden {
            guard let manualCategoryID = sample.manualCategoryID else { continue }

            let appPattern = normalizePattern(sample.applicationName)
            if !appPattern.isEmpty, !existingAppRules.contains(appPattern) {
                let key = "app:\(appPattern):\(manualCategoryID)"
                accumulators[key, default: SuggestionAccumulator(kind: .application, pattern: appPattern, categoryID: manualCategoryID)].sampleCount += 1
                accumulators[key, default: SuggestionAccumulator(kind: .application, pattern: appPattern, categoryID: manualCategoryID)].totalDuration += sample.duration
            }

            if let domain = sample.webDomain {
                let normalizedDomain = normalizePattern(domain, for: .domain)
                if !normalizedDomain.isEmpty, !existingDomainRules.contains(normalizedDomain) {
                    let key = "domain:\(normalizedDomain):\(manualCategoryID)"
                    accumulators[key, default: SuggestionAccumulator(kind: .domain, pattern: normalizedDomain, categoryID: manualCategoryID)].sampleCount += 1
                    accumulators[key, default: SuggestionAccumulator(kind: .domain, pattern: normalizedDomain, categoryID: manualCategoryID)].totalDuration += sample.duration
                }
            }
        }

        return accumulators.values
            .filter { $0.sampleCount >= 2 || $0.totalDuration >= 600 }
            .compactMap { item in
                guard let recommendedCategory = category(for: item.categoryID) else { return nil }
                let confidence = min(0.98, 0.52 + (Double(item.sampleCount) * 0.08) + min(item.totalDuration / 7200, 0.18))
                let reason = item.kind == .application
                    ? "Voce recategorizou este app manualmente varias vezes."
                    : "Voce recategorizou este site manualmente varias vezes."
                return ClassificationSuggestion(
                    id: "\(item.kind.rawValue):\(item.pattern):\(item.categoryID)",
                    kind: item.kind,
                    pattern: item.pattern,
                    recommendedCategory: recommendedCategory,
                    sampleCount: item.sampleCount,
                    totalDuration: item.totalDuration,
                    reason: reason,
                    confidence: confidence
                )
            }
            .sorted {
                if $0.sampleCount == $1.sampleCount {
                    return $0.totalDuration > $1.totalDuration
                }

                return $0.sampleCount > $1.sampleCount
            }
    }

    func applySuggestion(_ suggestion: ClassificationSuggestion) {
        switch suggestion.kind {
        case .application:
            assignCategory(toApplication: suggestion.pattern, categoryID: suggestion.recommendedCategory.id)
        case .domain:
            assignCategory(toDomain: suggestion.pattern, categoryID: suggestion.recommendedCategory.id)
        }
    }

    func weeklyReport(containing day: Date) -> WeeklyReport {
        let calendar = Calendar.autoupdatingCurrent
        let normalizedDay = calendar.startOfDay(for: day)
        let weekday = calendar.component(.weekday, from: normalizedDay)
        let startOffset = weekday == 1 ? -6 : 2 - weekday
        let weekStart = calendar.date(byAdding: .day, value: startOffset, to: normalizedDay) ?? normalizedDay
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? normalizedDay

        var days: [WeeklyReportDay] = []
        var combinedCategories: [ActivityCategory: TimeInterval] = [:]
        var combinedApps: [String: AggregateBucket] = [:]
        var combinedSites: [String: AggregateBucket] = [:]
        var totalTrackedTime: TimeInterval = 0

        var cursor = weekStart
        while cursor < weekEnd {
            let summary = summary(for: cursor)
            totalTrackedTime += summary.totalTrackedTime
            days.append(WeeklyReportDay(date: cursor, trackedTime: summary.totalTrackedTime, topCategory: summary.categoryBreakdown.first))

            for bucket in summary.categoryBreakdown {
                combinedCategories[bucket.category, default: 0] += bucket.duration
            }

            for item in summary.appBreakdown {
                var bucket = combinedApps[item.label, default: AggregateBucket(label: item.label, secondaryLabel: item.secondaryLabel, systemImage: item.systemImage)]
                bucket.duration += item.duration
                if let category = item.category {
                    bucket.categoryTotals[category, default: 0] += item.duration
                }
                combinedApps[item.label] = bucket
            }

            for item in summary.websiteBreakdown {
                var bucket = combinedSites[item.label, default: AggregateBucket(label: item.label, secondaryLabel: item.secondaryLabel, systemImage: item.systemImage)]
                bucket.duration += item.duration
                if let category = item.category {
                    bucket.categoryTotals[category, default: 0] += item.duration
                }
                combinedSites[item.label] = bucket
            }

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? weekEnd
        }

        let weekSamples = visibleSamples(from: weekStart, to: weekEnd)
            .sorted { $0.startDate < $1.startDate }

        let contextSwitches = max(weekSamples.count - 1, 0)
        let focusIDs = Set(focusProfiles.filter { $0.kind == .focus }.flatMap(\.categoryIDs))
        let distractionIDs = Set(focusProfiles.filter { $0.kind == .distraction }.flatMap(\.categoryIDs))

        var focusTime: TimeInterval = 0
        var distractionTime: TimeInterval = 0
        for sample in weekSamples {
            let categoryID = classifier.classify(sample: sample, preferences: monitoringPreferences).id
            if focusIDs.contains(categoryID) {
                focusTime += sample.duration
            }
            if distractionIDs.contains(categoryID) {
                distractionTime += sample.duration
            }
        }

        let topCategories = combinedCategories
            .map { CategoryBreakdown(category: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }

        let topApps = combinedApps.values.map(\.item).sorted { $0.duration > $1.duration }
        let topSites = combinedSites.values.map(\.item).sorted { $0.duration > $1.duration }

        let weeklyCategoryTotals = Dictionary(uniqueKeysWithValues: topCategories.map { ($0.category.id, $0.duration) })
        let goalProgress = usageGoals
            .filter { $0.isEnabled }
            .compactMap { goal -> GoalProgress? in
                guard let resolvedCategory = category(for: goal.categoryID) else { return nil }
                let currentDuration: TimeInterval

                switch goal.period {
                case .daily:
                    currentDuration = summary(for: normalizedDay).categoryBreakdown.first(where: { $0.category.id == goal.categoryID })?.duration ?? 0
                case .weekly:
                    currentDuration = weeklyCategoryTotals[goal.categoryID] ?? 0
                }

                return GoalProgress(goal: goal, category: resolvedCategory, currentDuration: currentDuration)
            }

        let averageDailyTrackedTime = totalTrackedTime / 7
        var highlights: [String] = []

        if let topCategory = topCategories.first {
            highlights.append("A categoria lider da semana foi \(topCategory.category.title) com \(LuumFormatters.duration(topCategory.duration)).")
        }
        if focusTime > 0 {
            highlights.append("Os perfis de foco acumularam \(LuumFormatters.duration(focusTime)) nesta semana.")
        }
        if distractionTime > 0 {
            highlights.append("Os perfis de distracao somaram \(LuumFormatters.duration(distractionTime)) nesta semana.")
        }
        highlights.append("O luum registrou \(contextSwitches) trocas de contexto ao longo da semana.")

        return WeeklyReport(
            startDate: weekStart,
            endDate: weekEnd.addingTimeInterval(-1),
            totalTrackedTime: totalTrackedTime,
            averageDailyTrackedTime: averageDailyTrackedTime,
            contextSwitches: contextSwitches,
            focusTime: focusTime,
            distractionTime: distractionTime,
            topCategories: Array(topCategories.prefix(5)),
            topApps: Array(topApps.prefix(5)),
            topSites: Array(topSites.prefix(5)),
            goalProgress: goalProgress,
            days: days,
            highlights: highlights
        )
    }

    var teamRankingUsesPreviewData: Bool {
        workspaceRankingEntries.isEmpty
    }

    func teamRanking(for day: Date) -> [TeamRankingEntry] {
        if !workspaceRankingEntries.isEmpty {
            return workspaceRankingEntries.sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.trackedTime > rhs.trackedTime
                }
                return lhs.score > rhs.score
            }
        }

        let report = weeklyReport(containing: day)
        let currentUser = TeamRankingEntry(
            id: "me",
            displayName: teamSettings.memberDisplayName,
            roleLabel: teamSettings.roleLabel,
            trackedTime: report.totalTrackedTime,
            focusTime: report.focusTime,
            plannedTime: max(report.totalTrackedTime * 0.92, report.averageDailyTrackedTime * 5),
            contextSwitches: report.contextSwitches,
            score: makeTeamScore(
                trackedTime: report.totalTrackedTime,
                focusTime: report.focusTime,
                plannedTime: max(report.totalTrackedTime * 0.92, report.averageDailyTrackedTime * 5),
                contextSwitches: report.contextSwitches
            ),
            isCurrentUser: true
        )

        let previewMembers = [
            ("Ana Martins", "Produto", 1.14, 1.10, 0.98, 0.86),
            ("Caio Lopes", "Design", 0.92, 0.88, 1.02, 1.18),
            ("Marina Costa", "Sucesso do cliente", 1.08, 0.95, 1.04, 0.91),
            ("Rafael Gomes", "Engenharia", 1.22, 1.18, 1.10, 0.79),
        ]

        let previewEntries = previewMembers.enumerated().map { index, member in
            let trackedTime = max(3_600, report.totalTrackedTime * member.2)
            let focusTime = max(1_800, report.focusTime * member.3)
            let plannedTime = max(3_600, currentUser.plannedTime * member.4)
            let contextSwitches = max(8, Int((Double(report.contextSwitches) * member.5).rounded()))

            return TeamRankingEntry(
                id: "preview-\(index)",
                displayName: member.0,
                roleLabel: member.1,
                trackedTime: trackedTime,
                focusTime: focusTime,
                plannedTime: plannedTime,
                contextSwitches: contextSwitches,
                score: makeTeamScore(
                    trackedTime: trackedTime,
                    focusTime: focusTime,
                    plannedTime: plannedTime,
                    contextSwitches: contextSwitches
                ),
                isCurrentUser: false
            )
        }

        return ([currentUser] + previewEntries).sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.trackedTime > rhs.trackedTime
            }

            return lhs.score > rhs.score
        }
    }

    func searchResults(matching rawQuery: String, limit: Int = 80) -> [GlobalSearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        var activityResults: [GlobalSearchResult] = []
        activityResults.reserveCapacity(min(limit, 80))

        for sample in samples.reversed() where activityResults.count < limit {
            guard !sample.isHidden && !isIgnored(sample: sample) else { continue }

            let haystack = [
                sample.applicationName,
                sample.bundleIdentifier ?? "",
                sample.webDomain ?? "",
                sample.pageTitle ?? "",
                sample.webURL ?? "",
                sample.note ?? "",
                classifier.searchQuery(from: sample.webURL) ?? "",
            ]
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            guard haystack.contains(normalizedQuery) else { continue }

            let resolvedCategory = classifier.classify(sample: sample, preferences: monitoringPreferences)
            activityResults.append(
                GlobalSearchResult(
                    id: sample.id.uuidString,
                    kind: .activity,
                    date: sample.startDate,
                    title: sample.pageTitle ?? sample.applicationName,
                    subtitle: sample.webDomain ?? sample.applicationName,
                    footnote: LuumFormatters.timeRange(start: sample.startDate, end: sample.endDate),
                    category: resolvedCategory
                )
            )
        }

        let remainingLimit = max(0, limit - activityResults.count)
        guard remainingLimit > 0 else {
            return activityResults.sorted { $0.date > $1.date }
        }

        let planningEvents =
            googleCalendarConnections
                .filter(\.isEnabled)
                .flatMap(\.agendaItems)
            + notionAgendaItems
            + outlookAgendaItems
            + clickUpAgendaItems
            + linearAgendaItems

        let agendaResults = planningEvents
            .sorted { $0.startDate > $1.startDate }
            .compactMap { event -> GlobalSearchResult? in
                let haystack = [
                    event.title,
                    event.location ?? "",
                    event.calendarTitle,
                    event.accountLabel,
                    event.notes ?? "",
                ]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

                guard haystack.contains(normalizedQuery) else { return nil }

                return GlobalSearchResult(
                    id: "agenda-\(event.id)",
                    kind: .agenda,
                    date: event.startDate,
                    title: event.title,
                    subtitle: "\(event.accountLabel) • \(event.calendarTitle)",
                    footnote: event.isAllDay ? "Dia inteiro" : LuumFormatters.timeRange(start: event.startDate, end: event.endDate),
                    category: nil
                )
            }
            .prefix(remainingLimit)

        return (activityResults + Array(agendaResults)).sorted { $0.date > $1.date }
    }

    func exportWeeklyReport(containing day: Date, format: ExportFormat) {
        let report = weeklyReport(containing: day)
        let fileManager = FileManager.default
        let downloadsURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent("luum-exports", isDirectory: true)

        do {
            try fileManager.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
            let dateToken = report.startDate.formatted(.dateTime.year().month().day())
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: " ", with: "-")
            let fileURL = downloadsURL.appendingPathComponent("luum-weekly-report-\(dateToken).\(format.fileExtension)")

            switch format {
            case .json:
                let payload = WeeklyReportExportPayload(
                    startDate: report.startDate,
                    endDate: report.endDate,
                    totalTrackedTime: report.totalTrackedTime,
                    averageDailyTrackedTime: report.averageDailyTrackedTime,
                    contextSwitches: report.contextSwitches,
                    focusTime: report.focusTime,
                    distractionTime: report.distractionTime,
                    topCategories: report.topCategories.map { WeeklyExportBreakdown(label: $0.category.title, duration: $0.duration) },
                    topApps: report.topApps.map { WeeklyExportBreakdown(label: $0.label, duration: $0.duration) },
                    topSites: report.topSites.map { WeeklyExportBreakdown(label: $0.label, duration: $0.duration) },
                    highlights: report.highlights
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(payload)
                try data.write(to: fileURL, options: .atomic)
            case .csv:
                let header = "type,label,duration_minutes\n"
                let categoryLines = report.topCategories.map { "category,\($0.category.title),\(Int(($0.duration / 60).rounded()))" }
                let appLines = report.topApps.map { "app,\($0.label),\(Int(($0.duration / 60).rounded()))" }
                let siteLines = report.topSites.map { "site,\($0.label),\(Int(($0.duration / 60).rounded()))" }
                let csv = header + (categoryLines + appLines + siteLines).joined(separator: "\n")
                guard let data = csv.data(using: .utf8) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try data.write(to: fileURL, options: .atomic)
            }

            exportStatusMessage = "Exportado para \(fileURL.path)."
        } catch {
            exportStatusMessage = error.localizedDescription
        }
    }

    func emailWeeklyReport(containing day: Date) {
        guard !isSendingWeeklyReportEmail else { return }
        guard canUse(.weeklyReportEmail) else {
            exportStatusMessage = lockMessage(for: .weeklyReportEmail)
            return
        }

        isSendingWeeklyReportEmail = true
        exportStatusMessage = "Gerando PDF e preparando envio por email..."

        weeklyReportEmailTask?.cancel()
        weeklyReportEmailTask = Task { [weak self] in
            await self?.runWeeklyReportEmail(containing: day)
        }
    }

    func checkWeeklyReportEmailHealth() {
        guard !isCheckingWeeklyReportEmailHealth else { return }

        isCheckingWeeklyReportEmailHealth = true
        weeklyReportEmailHealthMessage = "Verificando Gemini e email na Vercel..."
        weeklyReportEmailHealthTask?.cancel()
        weeklyReportEmailHealthTask = Task { [weak self] in
            await self?.runWeeklyReportEmailHealthCheck()
        }
    }

    private func runWeeklyReportEmailHealthCheck() async {
        defer { isCheckingWeeklyReportEmailHealth = false }

        do {
            let health = try await weeklyReportEmailService.health()
            guard !Task.isCancelled else { return }
            weeklyReportEmailHealthMessage = Self.weeklyReportEmailHealthMessage(for: health)
        } catch is CancellationError {
            return
        } catch {
            weeklyReportEmailHealthMessage = error.localizedDescription
        }
    }

    static func weeklyReportEmailHealthMessage(for health: WeeklyReportEmailHealth) -> String {
        if health.ok {
            return "PDF por email pronto: Gemini \(health.gemini.model) e \(health.email.provider) configurados."
        }
        var missing: [String] = []
        if !health.gemini.configured {
            missing.append("Gemini")
        }
        if !health.email.apiKeyConfigured {
            missing.append("Resend")
        }
        if !health.email.fromConfigured {
            missing.append("email de envio")
        }
        let detail = missing.isEmpty ? "configuracao da Vercel" : missing.joined(separator: ", ")
        return "PDF por email pendente: configure \(detail) na Vercel."
    }

    private func runWeeklyReportEmail(containing day: Date) async {
        defer { isSendingWeeklyReportEmail = false }

        do {
            let verified = try await verifiedAuthSessionForProtectedRequest()
            guard verified.includes(.weeklyReportEmail) else {
                exportStatusMessage = lockMessage(for: .weeklyReportEmail)
                return
            }
            guard !verified.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                exportStatusMessage = "Sua conta Firebase precisa ter email para receber o PDF."
                return
            }

            let response = try await weeklyReportEmailService.send(
                firebaseToken: verified.idToken,
                report: weeklyReportEmailPayload(containing: day)
            )
            guard isCurrentVerifiedSession(verified) else { return }
            exportStatusMessage = response.emailed
                ? "PDF enviado para \(verified.email): \(response.fileName)."
                : "PDF gerado: \(response.fileName)."
        } catch is CancellationError {
            return
        } catch {
            exportStatusMessage = error.localizedDescription
        }
    }

    private func weeklyReportEmailPayload(containing day: Date) -> WeeklyReportEmailPayload {
        let report = weeklyReport(containing: day)
        return WeeklyReportEmailPayload(
            startDate: Self.reportDateString(report.startDate),
            endDate: Self.reportDateString(report.endDate),
            totalTrackedTime: report.totalTrackedTime,
            averageDailyTrackedTime: report.averageDailyTrackedTime,
            contextSwitches: report.contextSwitches,
            focusTime: report.focusTime,
            distractionTime: report.distractionTime,
            topCategories: report.topCategories.map {
                WeeklyReportEmailBreakdown(label: $0.category.title, duration: $0.duration)
            },
            topApps: report.topApps.map {
                WeeklyReportEmailBreakdown(label: $0.label, duration: $0.duration)
            },
            topSites: report.topSites.map {
                WeeklyReportEmailBreakdown(label: $0.label, duration: $0.duration)
            },
            highlights: report.highlights
        )
    }

    private static func reportDateString(_ date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    func handleOnboardingAction(_ itemID: String, day: Date = Date()) {
        switch itemID {
        case "monitoring":
            startMonitoring()
        case "google-client", "google-account":
            connectGoogleCalendar(for: day)
        case "notifications":
            requestNotificationAuthorization()
        case "browser-data":
            break
        default:
            break
        }
    }

    private func runCalendarConnect(for day: Date) async {
        guard canUse(.agendaIntegrations) else {
            googleCalendarStatusMessage = lockMessage(for: .agendaIntegrations)
            return
        }

        var clientID = googleCalendarClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = googleCalendarClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        if clientID.isEmpty {
            do {
                googleCalendarStatusMessage = "Carregando configuracao gerenciada do Google Calendar..."
                let config = try await publicIntegrationConfigService.fetch()
                publicIntegrationConfig = config
                clientID = config.googleCalendar.clientID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !clientID.isEmpty {
                    googleCalendarClientID = clientID
                    persistGoogleCalendar()
                }
            } catch {
                googleCalendarStatusMessage = error.localizedDescription
                return
            }
        }

        guard !clientID.isEmpty else {
            googleCalendarStatusMessage = "Google Calendar ainda nao foi configurado no admin do Luum. Configure GOOGLE_CALENDAR_CLIENT_ID uma vez para liberar conexao com um clique."
            return
        }

        isConnectingGoogleCalendar = true
        defer { isConnectingGoogleCalendar = false }

        do {
            let result = try await googleCalendarService.connect(
                clientID: clientID,
                clientSecret: clientSecret,
                day: day
            )

            guard let profile = result.profile else {
                googleCalendarStatusMessage = "Nao foi possivel identificar a conta Google conectada."
                return
            }

            let connectionID = slugify(profile.email)
            try storeCalendarTokens(result.tokens, connectionID: connectionID)

            let connection = GoogleCalendarConnectionSnapshot(
                id: connectionID,
                profile: profile,
                calendars: result.calendars,
                agendaDay: Calendar.autoupdatingCurrent.startOfDay(for: day),
                agendaItems: result.events,
                lastSyncAt: result.syncedAt,
                isEnabled: true
            )

            if let existingIndex = googleCalendarConnections.firstIndex(where: { $0.id == connectionID }) {
                googleCalendarConnections[existingIndex] = connection
            } else {
                googleCalendarConnections.append(connection)
                googleCalendarConnections.sort { $0.profile.email < $1.profile.email }
            }

            googleCalendarStatusMessage = "Conta \(profile.email) conectada com sucesso."
            persistGoogleCalendar()
            scheduleCloudSyncIfNeeded(reason: "calendar-connect")
        } catch {
            googleCalendarStatusMessage = error.localizedDescription
        }
    }

    private func runPublicIntegrationConfigRefresh() async {
        isLoadingPublicIntegrationConfig = true
        publicIntegrationStatusMessage = "Verificando conexoes disponiveis no Luum..."
        defer { isLoadingPublicIntegrationConfig = false }

        do {
            let config = try await publicIntegrationConfigService.fetch()
            publicIntegrationConfig = config
            if let clientID = config.googleCalendar.clientID?.trimmingCharacters(in: .whitespacesAndNewlines),
               !clientID.isEmpty,
               googleCalendarClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                googleCalendarClientID = clientID
                persistGoogleCalendar()
            }

            let availableCount = [
                config.managedOAuth.googleCalendar,
                config.managedOAuth.outlookCalendar,
                config.managedOAuth.notion,
                config.managedOAuth.clickUp,
                config.managedOAuth.linear,
                config.managedOAuth.zapier,
            ]
            .filter { $0 }
            .count

            publicIntegrationStatusMessage = switch availableCount {
            case 0:
                "As proximas conexoes guiadas ainda estao sendo preparadas."
            case 1:
                "1 conexao guiada disponivel pela conta Luum."
            default:
                "\(availableCount) conexoes guiadas disponiveis pela conta Luum."
            }
        } catch {
            publicIntegrationStatusMessage = error.localizedDescription
        }
    }

    private func runCalendarSync(for day: Date, force: Bool) async {
        guard canUse(.agendaIntegrations) else {
            if force {
                googleCalendarStatusMessage = lockMessage(for: .agendaIntegrations)
            }
            return
        }

        let clientID = googleCalendarClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = googleCalendarClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !googleCalendarConnections.isEmpty else {
            if force, isGoogleCalendarConfigured {
                googleCalendarStatusMessage = "Conecte pelo menos uma conta Google para sincronizar a agenda."
            }
            return
        }

        isSyncingGoogleCalendar = true
        defer { isSyncingGoogleCalendar = false }

        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        var updatedConnections = googleCalendarConnections
        var syncMessages: [String] = []

        await withTaskGroup(of: (String, Result<GoogleCalendarSyncResult, Error>).self) { group in
            for connection in googleCalendarConnections where connection.isEnabled {
                guard let tokens = loadCalendarTokens(connectionID: connection.id) else {
                    syncMessages.append("A conta \(connection.profile.email) precisa ser conectada novamente.")
                    continue
                }

                let storedDay = connection.agendaDay.map { Calendar.autoupdatingCurrent.startOfDay(for: $0) }
                let isToday = normalizedDay == Calendar.autoupdatingCurrent.startOfDay(for: Date())
                let lastSyncAge = connection.lastSyncAt.map { Date().timeIntervalSince($0) } ?? .infinity
                let shouldReuseCurrentAgenda = !force &&
                    storedDay == normalizedDay &&
                    !connection.agendaItems.isEmpty &&
                    (!isToday || lastSyncAge < calendarRefreshInterval) &&
                    !tokens.needsRefresh

                guard !shouldReuseCurrentAgenda else { continue }

                group.addTask { [googleCalendarService] in
                    do {
                        let result = try await googleCalendarService.refresh(
                            day: day,
                            clientID: clientID,
                            clientSecret: clientSecret,
                            existingTokens: tokens,
                            connectionID: connection.id,
                            connectionProfile: connection.profile,
                            existingCalendars: connection.calendars
                        )
                        return (connection.id, .success(result))
                    } catch {
                        return (connection.id, .failure(error))
                    }
                }
            }

            for await item in group {
                let connectionID = item.0
                let result = item.1

                guard let index = updatedConnections.firstIndex(where: { $0.id == connectionID }) else { continue }

                switch result {
                case let .success(syncResult):
                    updatedConnections[index].profile = syncResult.profile ?? updatedConnections[index].profile
                    updatedConnections[index].calendars = syncResult.calendars
                    updatedConnections[index].agendaItems = syncResult.events
                    updatedConnections[index].agendaDay = normalizedDay
                    updatedConnections[index].lastSyncAt = syncResult.syncedAt

                    do {
                        try storeCalendarTokens(syncResult.tokens, connectionID: connectionID)
                    } catch {
                        syncMessages.append(error.localizedDescription)
                    }
                case let .failure(error):
                    syncMessages.append(error.localizedDescription)
                }
            }
        }

            googleCalendarConnections = updatedConnections
        persistGoogleCalendar()
        scheduleCloudSyncIfNeeded(reason: "calendar-sync")

        if !syncMessages.isEmpty {
            googleCalendarStatusMessage = syncMessages.joined(separator: "\n")
        } else if force {
            googleCalendarStatusMessage = "Agenda sincronizada em \(googleCalendarConnections.count) conta(s)."
        }

        if syncMessages.isEmpty {
            let totalEvents = googleCalendarConnections
                .filter(\.isEnabled)
                .flatMap(\.agendaItems)
                .count
            await sendZapierCalendarSyncEventIfNeeded(source: "google", itemCount: totalEvents)
        }
    }

    private func runNotionCalendarSync(for day: Date, force: Bool) async {
        guard canUse(.advancedIntegrations) else {
            if force {
                notionCalendarStatusMessage = lockMessage(for: .advancedIntegrations)
            }
            return
        }

        let settings = notionCalendarSettings.normalized()

        guard settings.isEnabled else {
            if force {
                notionCalendarStatusMessage = "Ative a integracao do Notion para sincronizar esta fonte."
            }
            return
        }

        guard notionCalendarConfigured else {
            if force {
                notionCalendarStatusMessage = Self.notionPendingConnectionMessage
            }
            return
        }

        guard let token = keychainService.string(for: Self.notionCalendarTokenKey),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            notionCalendarStatusMessage = NotionCalendarIssue.missingToken.errorDescription
            return
        }

        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let lastSyncAge = settings.lastSyncAt.map { Date().timeIntervalSince($0) } ?? .infinity
        let shouldReuseCurrentAgenda = !force &&
            notionAgendaDay == normalizedDay &&
            !notionAgendaItems.isEmpty &&
            lastSyncAge < calendarRefreshInterval

        guard !shouldReuseCurrentAgenda else { return }

        isSyncingNotionCalendar = true
        defer { isSyncingNotionCalendar = false }

        do {
            let result = try await notionCalendarService.refresh(
                day: normalizedDay,
                settings: settings,
                token: token
            )

            notionAgendaItems = result.events
            notionAgendaDay = normalizedDay
            monitoringPreferences.notionCalendarSettings.lastSyncAt = result.syncedAt
            notionCalendarStatusMessage = result.events.isEmpty
                ? "Notion sincronizado sem eventos na janela atual."
                : "Notion sincronizado em \(result.dataSourceIDs.count) fonte(s)."
            persistMonitoringPreferences()
            await sendZapierCalendarSyncEventIfNeeded(source: "notion", itemCount: result.events.count)
        } catch {
            notionCalendarStatusMessage = error.localizedDescription
        }
    }

    private func runOutlookCalendarSync(for day: Date, force: Bool) async {
        guard canUse(.agendaIntegrations) else {
            if force {
                outlookCalendarStatusMessage = lockMessage(for: .agendaIntegrations)
            }
            return
        }

        let settings = outlookCalendarSettings.normalized()

        guard settings.isEnabled else {
            if force {
                outlookCalendarStatusMessage = "Ative a integracao do Outlook para sincronizar esta fonte."
            }
            return
        }

        guard outlookCalendarConfigured else {
            if force {
                outlookCalendarStatusMessage = Self.outlookPendingConnectionMessage
            }
            return
        }

        guard let token = keychainService.string(for: Self.outlookCalendarTokenKey),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            outlookCalendarStatusMessage = OutlookCalendarIssue.missingToken.errorDescription
            return
        }

        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let lastSyncAge = settings.lastSyncAt.map { Date().timeIntervalSince($0) } ?? .infinity
        let shouldReuseCurrentAgenda = !force &&
            outlookAgendaDay == normalizedDay &&
            !outlookAgendaItems.isEmpty &&
            lastSyncAge < calendarRefreshInterval
        guard !shouldReuseCurrentAgenda else { return }

        isSyncingOutlookCalendar = true
        defer { isSyncingOutlookCalendar = false }

        do {
            let result = try await outlookCalendarService.sync(
                day: normalizedDay,
                settings: settings,
                accessToken: token
            )
            outlookAgendaItems = result.events
            outlookAgendaDay = normalizedDay
            monitoringPreferences.outlookCalendarSettings.accountEmail = result.accountEmail
            monitoringPreferences.outlookCalendarSettings.calendars = result.calendars
            monitoringPreferences.outlookCalendarSettings.lastSyncAt = result.syncedAt
            outlookCalendarStatusMessage = result.events.isEmpty
                ? "Outlook sincronizado sem eventos na janela atual."
                : "Outlook sincronizado em \(result.calendars.filter(\.isSelected).count) calendario(s)."
            persistMonitoringPreferences()
            await sendZapierCalendarSyncEventIfNeeded(source: "outlook", itemCount: result.events.count)
        } catch {
            outlookCalendarStatusMessage = error.localizedDescription
        }
    }

    private func runClickUpSync(for day: Date, force: Bool) async {
        guard canUse(.agendaIntegrations) else {
            if force {
                clickUpStatusMessage = lockMessage(for: .agendaIntegrations)
            }
            return
        }

        let settings = clickUpSettings.normalized()

        guard settings.isEnabled else {
            if force {
                clickUpStatusMessage = "Ative a integracao do ClickUp para sincronizar esta fonte."
            }
            return
        }

        guard clickUpConfigured else {
            if force {
                clickUpStatusMessage = Self.clickUpPendingConnectionMessage
            }
            return
        }

        guard let token = keychainService.string(for: Self.clickUpTokenKey),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            clickUpStatusMessage = ClickUpIssue.missingToken.errorDescription
            return
        }

        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let lastSyncAge = settings.lastSyncAt.map { Date().timeIntervalSince($0) } ?? .infinity
        let shouldReuseCurrentAgenda = !force &&
            clickUpAgendaDay == normalizedDay &&
            !clickUpAgendaItems.isEmpty &&
            lastSyncAge < calendarRefreshInterval
        guard !shouldReuseCurrentAgenda else { return }

        isSyncingClickUp = true
        defer { isSyncingClickUp = false }

        do {
            let result = try await clickUpService.sync(
                day: normalizedDay,
                settings: settings,
                apiToken: token
            )
            clickUpAgendaItems = result.events
            clickUpAgendaDay = normalizedDay
            monitoringPreferences.clickUpSettings.lastSyncAt = result.syncedAt
            clickUpStatusMessage = result.events.isEmpty
                ? "ClickUp sincronizado sem tarefas com prazo na janela atual."
                : "ClickUp sincronizado em \(result.listIDs.count) lista(s)."
            persistMonitoringPreferences()
            await sendZapierCalendarSyncEventIfNeeded(source: "clickup", itemCount: result.events.count)
        } catch {
            clickUpStatusMessage = error.localizedDescription
        }
    }

    private func runLinearSync(for day: Date, force: Bool) async {
        guard canUse(.agendaIntegrations) else {
            if force {
                linearStatusMessage = lockMessage(for: .agendaIntegrations)
            }
            return
        }

        let settings = linearSettings.normalized()

        guard settings.isEnabled else {
            if force {
                linearStatusMessage = "Ative a integracao do Linear para sincronizar esta fonte."
            }
            return
        }

        guard linearConfigured else {
            if force {
                linearStatusMessage = Self.linearPendingConnectionMessage
            }
            return
        }

        guard let token = keychainService.string(for: Self.linearTokenKey),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            linearStatusMessage = LinearIssue.missingToken.errorDescription
            return
        }

        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let lastSyncAge = settings.lastSyncAt.map { Date().timeIntervalSince($0) } ?? .infinity
        let shouldReuseCurrentAgenda = !force &&
            linearAgendaDay == normalizedDay &&
            !linearAgendaItems.isEmpty &&
            lastSyncAge < calendarRefreshInterval
        guard !shouldReuseCurrentAgenda else { return }

        isSyncingLinear = true
        defer { isSyncingLinear = false }

        do {
            let result = try await linearService.sync(
                day: normalizedDay,
                settings: settings,
                apiKey: token
            )
            linearAgendaItems = result.events
            linearAgendaDay = normalizedDay
            monitoringPreferences.linearSettings.lastSyncAt = result.syncedAt
            linearStatusMessage = result.events.isEmpty
                ? "Linear sincronizado sem issues com prazo na janela atual."
                : "Linear sincronizado em \(result.teamIDs.count) time(s)."
            persistMonitoringPreferences()
            await sendZapierCalendarSyncEventIfNeeded(source: "linear", itemCount: result.events.count)
        } catch {
            linearStatusMessage = error.localizedDescription
        }
    }

    private func runWorkspaceSync(for day: Date, force: Bool) async {
        guard teamWorkspaceConfigured else {
            if force {
                workspaceSyncStatusMessage = "Preencha endpoint, Workspace ID e chave para liberar o ranking corporativo."
            }
            return
        }

        guard let secret = workspaceSecret,
              !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            workspaceSyncStatusMessage = WorkspaceSyncError.missingSecret.errorDescription
            return
        }

        isSyncingWorkspace = true
        defer { isSyncingWorkspace = false }

        do {
            let verified = try await verifiedAuthSessionForProtectedRequest()
            guard verified.includes(.teamWorkspace) else {
                workspaceSyncStatusMessage = lockMessage(for: .teamWorkspace)
                return
            }
            let payload = makeWorkspaceMemberPayload(for: day)
            let updatedAt = try await workspaceSyncService.push(
                baseURL: FirebaseAuthService.defaultBaseURL,
                workspaceID: teamSettings.workspaceID,
                memberID: teamSettings.workspaceMemberID,
                secret: secret,
                firebaseToken: verified.idToken,
                payload: payload
            )
            guard isCurrentVerifiedSession(verified) else { return }
            let ranking = try await workspaceSyncService.fetchRanking(
                baseURL: FirebaseAuthService.defaultBaseURL,
                workspaceID: teamSettings.workspaceID,
                memberID: teamSettings.workspaceMemberID,
                secret: secret,
                firebaseToken: verified.idToken
            )
            guard isCurrentVerifiedSession(verified) else { return }
            workspaceRankingEntries = ranking.entries
            workspaceSyncLastSyncAt = ranking.updatedAt ?? updatedAt
            workspaceSyncStatusMessage = workspaceRankingEntries.isEmpty
                ? "Workspace sincronizado sem membros suficientes para ranking."
                : "Workspace sincronizado com \(workspaceRankingEntries.count) membro(s)."
            await sendZapierWorkspaceEventIfNeeded(memberCount: workspaceRankingEntries.count)
        } catch is CancellationError {
            return
        } catch {
            workspaceSyncStatusMessage = error.localizedDescription
        }
    }

    private func runAIClassification(kind: AIClassificationRequest.TargetKind, item: UsageBreakdownItem) async {
        guard !isClassifyingWithAI else { return }

        guard canUse(.classification) else {
            aiClassificationStatusMessage = lockMessage(for: .classification)
            return
        }

        let settings = aiClassificationSettings
        guard settings.isEnabled else {
            aiClassificationStatusMessage = "Ative a IA de classificacao nas preferencias."
            return
        }

        let usesLuumBackend = AIClassificationService.isLuumBackendEndpoint(settings.endpointURL)
        let apiKey = keychainService.string(for: Self.aiClassificationAPIKeyKey)
        let verifiedSession: LuumAuthSession?

        if usesLuumBackend {
            do {
                let verified = try await verifiedAuthSessionForProtectedRequest()
                guard verified.includes(.classification) else {
                    aiClassificationStatusMessage = lockMessage(for: .classification)
                    return
                }
                verifiedSession = verified
            } catch {
                aiClassificationStatusMessage = error.localizedDescription
                return
            }
        } else {
            guard !(apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) else {
                aiClassificationStatusMessage = "Use a IA segura do Luum para classificar sem configurar chave no app."
                return
            }
            verifiedSession = nil
        }

        isClassifyingWithAI = true
        aiClassificationStatusMessage = "IA analisando \(item.label)..."
        defer { isClassifyingWithAI = false }

        do {
            let result = try await aiClassificationService.classify(
                request: AIClassificationRequest(
                    kind: kind,
                    label: item.label,
                    secondaryLabel: item.secondaryLabel,
                    currentCategory: item.category,
                    categories: categories
                ),
                settings: settings,
                apiKey: apiKey,
                firebaseToken: verifiedSession?.idToken
            )

            if let verifiedSession, !isCurrentVerifiedSession(verifiedSession) {
                return
            }

            guard let category = category(for: result.categoryID) else {
                throw AIClassificationServiceError.unknownCategory(result.categoryID)
            }

            switch kind {
            case .application:
                assignCategory(toApplication: item.label, categoryID: category.id)
            case .domain:
                assignCategory(toDomain: item.label, categoryID: category.id)
            }

            let confidence = Int((result.confidence * 100).rounded())
            let reason = result.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            aiClassificationStatusMessage = reason.isEmpty
                ? "IA classificou \(item.label) como \(category.title) (\(confidence)%)."
                : "IA classificou \(item.label) como \(category.title) (\(confidence)%): \(reason)"
        } catch is CancellationError {
            return
        } catch {
            aiClassificationStatusMessage = error.localizedDescription
        }
    }

    private func runCloudSync() async {
        guard monitoringPreferences.cloudSyncSettings.isEnabled else { return }
        guard !isSyncingCloud else {
            cloudSyncPendingAfterCurrent = true
            return
        }

        isSyncingCloud = true
        defer {
            let shouldSchedulePendingSync = cloudSyncPendingAfterCurrent
            cloudSyncPendingAfterCurrent = false
            isSyncingCloud = false
            if shouldSchedulePendingSync {
                scheduleCloudSyncIfNeeded(reason: "pending-changes")
            }
        }

        do {
            let verified = try await verifiedAuthSessionForProtectedRequest()
            guard verified.includes(.cloudBackup) else {
                cloudSyncStatusMessage = lockMessage(for: .cloudBackup)
                return
            }
            guard cloudSyncConfigured else {
                cloudSyncStatusMessage = "Entre na conta Luum e valide o plano para ativar o backup Firebase."
                return
            }
            let updatedAt = try await cloudSyncService.push(
                baseURL: FirebaseAuthService.defaultBaseURL,
                backupID: verified.uid,
                firebaseToken: verified.idToken,
                payload: makeCloudBackupPayload()
            )
            guard isCurrentVerifiedSession(verified) else { return }
            cloudSyncLastSyncAt = updatedAt
            cloudSyncStatusMessage = "Backup sincronizado com sucesso."
        } catch is CancellationError {
            return
        } catch {
            cloudSyncStatusMessage = error.localizedDescription
        }
    }

    private func runCloudRestore() async {
        isSyncingCloud = true
        defer { isSyncingCloud = false }

        do {
            let verified = try await verifiedAuthSessionForProtectedRequest()
            guard verified.includes(.cloudBackup) else {
                cloudSyncStatusMessage = lockMessage(for: .cloudBackup)
                return
            }
            guard cloudSyncConfigured else {
                cloudSyncStatusMessage = "Entre na conta Luum e valide o plano antes de restaurar."
                return
            }
            guard let payload = try await cloudSyncService.pull(
                baseURL: FirebaseAuthService.defaultBaseURL,
                backupID: verified.uid,
                firebaseToken: verified.idToken
            ) else {
                cloudSyncStatusMessage = "Nenhum backup encontrado para esse identificador."
                return
            }
            guard isCurrentVerifiedSession(verified) else { return }

            monitoringPreferences = mergeRestoredMonitoringPreferences(payload.monitoringPreferences)
            googleCalendarClientID = payload.googleCalendarSnapshot.clientID
            googleCalendarConnections = payload.googleCalendarSnapshot.connections
            if canUse(.rawActivityBackup), let rawActivities = payload.rawActivities {
                samples = rawActivities
                sortSamples()
            }

            if !googleCalendarConnections.isEmpty {
                googleCalendarStatusMessage = "Estrutura da agenda restaurada. Se este Mac ainda nao tiver os tokens locais, reconecte as contas Google."
            }

            persistMonitoringPreferences()
            persistGoogleCalendar()
            schedulePersistence()
            invalidateSummaries()
            cloudSyncStatusMessage = "Backup restaurado com sucesso."
        } catch is CancellationError {
            return
        } catch {
            cloudSyncStatusMessage = error.localizedDescription
        }
    }

    private func makeCloudBackupPayload() -> CloudBackupPayload {
        let retentionDays = monitoringPreferences.privacySettings.retentionDays
        let summaries: [CloudDailySummarySnapshot]

        if monitoringPreferences.cloudSyncSettings.syncDailySummaries {
            let calendar = Calendar.autoupdatingCurrent
            summaries = (0 ..< retentionDays).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
                let summary = summary(for: day)
                guard summary.totalTrackedTime > 0 else { return nil }

                return CloudDailySummarySnapshot(
                    day: calendar.startOfDay(for: day),
                    totalTrackedTime: summary.totalTrackedTime,
                    categoryDurations: Dictionary(uniqueKeysWithValues: summary.categoryBreakdown.map { ($0.category.id, $0.duration) })
                )
            }
        } else {
            summaries = []
        }

        let rawActivities: [ActivitySample]?
        if monitoringPreferences.cloudSyncSettings.syncRawActivities && canUse(.rawActivityBackup) {
            rawActivities = samples.map(makeCloudSafeSample)
        } else {
            rawActivities = nil
        }

        return CloudBackupPayload(
            schemaVersion: 1,
            exportedAt: Date(),
            deviceName: Host.current().localizedName ?? "Mac",
            account: authSession.map {
                CloudAccountSnapshot(
                    uid: $0.uid,
                    email: $0.email,
                    displayName: $0.displayName,
                    plan: $0.plan,
                    subscriptionStatus: $0.subscriptionStatus
                )
            },
            monitoringPreferences: CloudSyncService.cloudSafePreferences(monitoringPreferences),
            googleCalendarSnapshot: CloudSyncService.cloudSafeGoogleCalendarSnapshot(
                clientID: googleCalendarClientID,
                connections: googleCalendarConnections
            ),
            dailySummaries: summaries,
            rawActivities: rawActivities
        )
    }

    private func makeCloudSafeSample(_ sample: ActivitySample) -> ActivitySample {
        guard monitoringPreferences.privacySettings.syncOnlyDomains else {
            return sample
        }

        var sanitized = sample
        sanitized.webURL = sample.webDomain.map { "https://\($0)" }
        sanitized.pageTitle = nil
        return sanitized
    }

    private func mergeRestoredMonitoringPreferences(_ restored: MonitoringPreferencesSnapshot) -> MonitoringPreferencesSnapshot {
        var merged = restored

        if !monitoringPreferences.cloudSyncSettings.syncCategoriesAndRules {
            merged.categories = monitoringPreferences.categories
            merged.categoryRules = monitoringPreferences.categoryRules
            merged.ignoredApplications = monitoringPreferences.ignoredApplications
            merged.ignoredDomains = monitoringPreferences.ignoredDomains
            merged.reminderProfiles = monitoringPreferences.reminderProfiles
        }

        merged.privacySettings = monitoringPreferences.privacySettings
        merged.cloudSyncSettings = monitoringPreferences.cloudSyncSettings
        return merged.normalized()
    }

    private func persistGoogleCalendar() {
        do {
            try googleCalendarPersistence.save(
                snapshot: GoogleCalendarSnapshot(
                    clientID: googleCalendarClientID,
                    clientSecret: "",
                    connections: googleCalendarConnections
                )
            )
        } catch {
            googleCalendarStatusMessage = "Nao foi possivel salvar a configuracao local da Google Agenda."
        }
    }

    private func persistMonitoringPreferences() {
        monitoringPreferences = monitoringPreferences.normalized()
        invalidateSummaries()

        scheduleMonitoringPreferencesSave(snapshot: monitoringPreferences)

        reconcileCurrentSnapshotAfterPreferencesChange()
        evaluateReminders()
        scheduleCloudSyncIfNeeded(reason: "preferences")
    }

    private func scheduleMonitoringPreferencesSave(snapshot: MonitoringPreferencesSnapshot) {
        preferencesWriteTask?.cancel()
        let monitoringPreferencesPersistence = monitoringPreferencesPersistence

        preferencesWriteTask = Task.detached(priority: .utility) { [snapshot, monitoringPreferencesPersistence, preferencesPersistenceDebounce, weak self] in
            do {
                try await Task.sleep(for: preferencesPersistenceDebounce)
                guard !Task.isCancelled else { return }
                try monitoringPreferencesPersistence.save(snapshot: snapshot)
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.automationStatusMessage = "Nao foi possivel salvar as preferencias de monitoramento."
                }
            }
        }
    }

    private func updateAutomationStatusMessage(_ message: String?) {
        guard automationStatusMessage != message else { return }
        automationStatusMessage = message
    }

    private func updateInputMonitoringMessage(_ message: String?) {
        guard inputMonitoringMessage != message else { return }
        inputMonitoringMessage = message
    }

    private func reconcileCurrentSnapshotAfterPreferencesChange() {
        guard let currentSnapshot else { return }
        if classifier.isIgnored(
            applicationName: currentSnapshot.applicationName,
            bundleIdentifier: currentSnapshot.bundleIdentifier,
            webURL: sanitizedURL(from: currentSnapshot.webURL),
            preferences: monitoringPreferences
        ) {
            closeCurrentSession(at: Date())
            currentFocusBlockMatch = nil
            focusShieldStatusMessage = nil
        }
    }

    private func ingest(_ snapshot: ActivitySnapshot) {
        let domain = classifier.domain(from: snapshot.webURL)
        let sanitizedURL = sanitizedURL(from: snapshot.webURL)
        let sanitizedTitle = sanitizedTitle(from: snapshot.pageTitle)

        if classifier.isIgnored(
            applicationName: snapshot.applicationName,
            bundleIdentifier: snapshot.bundleIdentifier,
            webURL: sanitizedURL,
            preferences: monitoringPreferences
        ) {
            currentSnapshot = nil
            currentFocusBlockMatch = nil
            focusShieldStatusMessage = nil
            closeCurrentSession(at: snapshot.timestamp)
            return
        }

        currentSnapshot = snapshot

        var affectedStart = snapshot.timestamp
        var affectedEnd = snapshot.timestamp
        var extendedCurrentSample = false

        if let lastIndex = samples.indices.last,
           samples[lastIndex].canExtend(with: snapshot, maximumGap: sessionGapTolerance, sanitizedURL: sanitizedURL, sanitizedTitle: sanitizedTitle) {
            extendedCurrentSample = true
            affectedStart = samples[lastIndex].startDate
            samples[lastIndex].endDate = snapshot.timestamp
            samples[lastIndex].webURL = sanitizedURL
            samples[lastIndex].webDomain = domain
            samples[lastIndex].pageTitle = sanitizedTitle
            affectedEnd = samples[lastIndex].endDate
        } else {
            if let lastIndex = samples.indices.last, snapshot.timestamp.timeIntervalSince(samples[lastIndex].endDate) <= sessionGapTolerance {
                affectedStart = min(affectedStart, samples[lastIndex].startDate)
                samples[lastIndex].endDate = max(samples[lastIndex].endDate, snapshot.timestamp)
                affectedEnd = max(affectedEnd, samples[lastIndex].endDate)
            }

            let newSample = ActivitySample(snapshot: snapshot, domain: domain, sanitizedURL: sanitizedURL, sanitizedTitle: sanitizedTitle)
            samples.append(newSample)
            affectedStart = min(affectedStart, newSample.startDate)
            affectedEnd = max(affectedEnd, newSample.endDate)
        }

        invalidateSummariesForActivity(
            from: affectedStart,
            to: affectedEnd,
            at: snapshot.timestamp,
            coalescingLiveExtension: extendedCurrentSample
        )
        schedulePersistence()
        evaluateReminders(force: !extendedCurrentSample, now: snapshot.timestamp)
    }

    private func closeCurrentSession(at timestamp: Date) {
        guard currentSnapshot != nil || !samples.isEmpty else { return }

        if let lastIndex = samples.indices.last, timestamp.timeIntervalSince(samples[lastIndex].endDate) <= sessionGapTolerance {
            let previousEndDate = samples[lastIndex].endDate
            samples[lastIndex].endDate = max(samples[lastIndex].endDate, timestamp)
            if samples[lastIndex].endDate != previousEndDate {
                invalidateSummaries(touching: samples[lastIndex])
            }
        }

        currentSnapshot = nil
        currentFocusBlockMatch = nil
        focusShieldStatusMessage = nil
        schedulePersistence()
    }

    private func schedulePersistence() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: self?.activityPersistenceDebounce ?? .seconds(5))
            guard !Task.isCancelled else { return }
            self?.flushPersistence()
        }
    }

    private func flushPersistence() {
        let retentionDays = monitoringPreferences.privacySettings.retentionDays
        let cleanedSamples = persistence.trim(samples: samples, retentionDays: retentionDays)
        if cleanedSamples != samples {
            samples = cleanedSamples
        }

        persistenceWriteTask?.cancel()
        let persistence = persistence

        persistenceWriteTask = Task.detached(priority: .utility) { [cleanedSamples, retentionDays, persistence, weak self] in
            do {
                try persistence.save(samples: cleanedSamples, retentionDays: retentionDays)
            } catch {
                await MainActor.run {
                    self?.automationStatusMessage = "Nao foi possivel salvar o historico local do luum."
                }
            }
        }
    }

    private func scheduleCloudSyncIfNeeded(reason _: String) {
        guard monitoringPreferences.cloudSyncSettings.isEnabled else { return }
        guard cloudSyncConfigured else { return }
        if isSyncingCloud {
            cloudSyncPendingAfterCurrent = true
            return
        }

        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.runCloudSync()
        }
    }

    private func startMaintenanceLoop() {
        guard maintenanceTask == nil else { return }

        maintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { return }
                await self?.performScheduledMaintenance()
            }
        }
    }

    private func performScheduledMaintenance() async {
        await reminderEngine.refreshAuthorizationStatus()

        if googleCalendarConnections.contains(where: \.isEnabled),
           !isConnectingGoogleCalendar,
           !isSyncingGoogleCalendar {
            await runCalendarSync(for: Date(), force: false)
        }

        if notionCalendarSettings.isEnabled,
           notionCalendarConfigured,
           !isSyncingNotionCalendar {
            await runNotionCalendarSync(for: Date(), force: false)
        }

        if outlookCalendarSettings.isEnabled,
           outlookCalendarConfigured,
           !isSyncingOutlookCalendar {
            await runOutlookCalendarSync(for: Date(), force: false)
        }

        if clickUpSettings.isEnabled,
           clickUpConfigured,
           !isSyncingClickUp {
            await runClickUpSync(for: Date(), force: false)
        }

        if linearSettings.isEnabled,
           linearConfigured,
           !isSyncingLinear {
            await runLinearSync(for: Date(), force: false)
        }

        if teamSettings.automaticallySyncWorkspace,
           teamSettings.sharesAnonymousMetrics,
           teamWorkspaceConfigured,
           !isSyncingWorkspace {
            await runWorkspaceSync(for: Date(), force: false)
        }

        guard monitoringPreferences.cloudSyncSettings.isEnabled,
              cloudSyncConfigured,
              !isSyncingCloud
        else {
            return
        }

        let lastSyncAge = cloudSyncLastSyncAt.map { Date().timeIntervalSince($0) } ?? .infinity
        guard lastSyncAge >= cloudSyncInterval else { return }
        await runCloudSync()
    }

    private func evaluateReminders(force: Bool = true, now: Date = Date()) {
        if Self.shouldSkipReminderEvaluation(
            force: force,
            lastRequestedAt: lastReminderEvaluationRequestAt,
            now: now,
            minimumInterval: reminderEvaluationMinimumInterval
        ) {
            return
        }
        lastReminderEvaluationRequestAt = now
        reminderEvaluationTask?.cancel()
        let canEvaluateReminders = canUse(.reminders)
        let canEvaluateFocusModes = canUse(.focusModes)

        guard canEvaluateReminders || canEvaluateFocusModes else {
            lastReminderStatusMessage = nil
            focusModeStatusMessage = nil
            focusShieldStatusMessage = nil
            currentFocusBlockMatch = nil
            return
        }

        reminderEvaluationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            let filteredSamples = self.visibleSamplesForCurrentStreak()
            if canEvaluateReminders {
                await self.reminderEngine.evaluate(
                    samples: filteredSamples,
                    preferences: self.monitoringPreferences,
                    classifier: self.classifier
                )
            }
            if canEvaluateFocusModes {
                await self.evaluateFocusModes(using: filteredSamples)
            }
        }
    }

    nonisolated static func shouldSkipReminderEvaluation(
        force: Bool,
        lastRequestedAt: Date?,
        now: Date,
        minimumInterval: TimeInterval
    ) -> Bool {
        guard !force, let lastRequestedAt else { return false }
        return now.timeIntervalSince(lastRequestedAt) < minimumInterval
    }

    private func evaluateFocusModes(using filteredSamples: [ActivitySample]) async {
        _ = filteredSamples
        await evaluateFocusShield()

        let insights = focusProfileInsights()
        guard let triggeredInsight = insights.first(where: \.isTriggered) else {
            focusModeStatusMessage = insights.first.map {
                "\($0.profile.title): \(LuumFormatters.duration($0.currentDuration)) dentro do perfil."
            }
            return
        }

        focusModeStatusMessage = "\(triggeredInsight.profile.title): \(triggeredInsight.messageSubtitle)"

        let lastDeliveredAt = focusModeDeliveries[triggeredInsight.profile.id]
        let minimumInterval = TimeInterval(max(900, triggeredInsight.profile.thresholdMinutes * 60))
        if let lastDeliveredAt, Date().timeIntervalSince(lastDeliveredAt) < minimumInterval {
            return
        }

        focusModeDeliveries[triggeredInsight.profile.id] = Date()
        await reminderEngine.triggerManualReminder(
            identifier: "luum-focus-\(triggeredInsight.profile.id.uuidString)",
            title: triggeredInsight.profile.title,
            message: triggeredInsight.profile.message,
            subtitle: triggeredInsight.messageSubtitle
        )
        await sendZapierFocusEventIfNeeded(
            type: "focus_profile_triggered",
            profileTitle: triggeredInsight.profile.title,
            details: [
                "duration": LuumFormatters.duration(triggeredInsight.currentDuration),
                "kind": triggeredInsight.profile.kind.title,
            ]
        )
    }

    private func evaluateFocusShield() async {
        guard let match = activeFocusBlockMatch() else {
            currentFocusBlockMatch = nil

            let armedProfiles = focusProfileInsights()
                .filter { $0.profile.hasBlockingRules && $0.isWithinSchedule && $0.profile.isEnabled }

            focusShieldStatusMessage = armedProfiles.isEmpty
                ? nil
                : "\(armedProfiles.count) perfil(is) com escudo pronto nesta janela."
            return
        }

        currentFocusBlockMatch = match
        focusShieldStatusMessage = "\(match.title) esta bloqueado por \(match.profile.title)."

        if let lastDeliveredAt = focusBlockDeliveries[match.id],
           Date().timeIntervalSince(lastDeliveredAt) < 300 {
            return
        }

        focusBlockDeliveries[match.id] = Date()
        await reminderEngine.triggerManualReminder(
            identifier: "luum-shield-\(match.id)",
            title: "Escudo de foco ativo",
            message: match.detail,
            subtitle: match.subtitle
        )
        await sendZapierFocusEventIfNeeded(
            type: "focus_block_triggered",
            profileTitle: match.profile.title,
            details: [
                "target": match.title,
                "kind": match.targetKind.title,
            ]
        )
    }

    private func isIgnored(sample: ActivitySample) -> Bool {
        classifier.isIgnored(
            applicationName: sample.applicationName,
            bundleIdentifier: sample.bundleIdentifier,
            webURL: sample.webURL,
            preferences: monitoringPreferences
        )
    }

    private func clip(sample: ActivitySample, from start: Date, to end: Date) -> ActivitySample? {
        let clippedStart = max(sample.startDate, start)
        let clippedEnd = min(sample.endDate, end)

        guard clippedEnd > clippedStart else {
            return nil
        }

        var clipped = sample
        clipped.startDate = clippedStart
        clipped.endDate = clippedEnd
        return clipped
    }

    private func visibleSamples(from start: Date, to end: Date) -> [ActivitySample] {
        var visibleSamples: [ActivitySample] = []

        for sample in samples {
            guard !sample.isHidden else { continue }
            if sample.startDate >= end { break }
            guard sampleOverlaps(sample, from: start, to: end) else { continue }
            guard let clipped = clip(sample: sample, from: start, to: end) else { continue }
            guard !isIgnored(sample: clipped) else { continue }
            visibleSamples.append(clipped)
        }

        return visibleSamples
    }

    private func visibleSamplesForCurrentStreak() -> [ActivitySample] {
        var reversedVisibleSamples: [ActivitySample] = []
        var nextSample: ActivitySample?

        for sample in samples.reversed() {
            guard !sample.isHidden, !isIgnored(sample: sample) else { continue }

            if let nextSample, nextSample.startDate.timeIntervalSince(sample.endDate) > 90 {
                break
            }

            reversedVisibleSamples.append(sample)
            nextSample = sample
        }

        return reversedVisibleSamples.reversed()
    }

    private func sampleOverlaps(_ sample: ActivitySample, from start: Date, to end: Date) -> Bool {
        sample.endDate > start && sample.startDate < end
    }

    private func continuousStreakDuration(for categoryIDs: Set<String>, in samples: [ActivitySample]) -> TimeInterval {
        guard let lastSample = samples.last else { return 0 }
        let lastCategoryID = classifier.classify(sample: lastSample, preferences: monitoringPreferences).id
        guard categoryIDs.contains(lastCategoryID) else { return 0 }

        var streakStart = lastSample.startDate
        var streakEnd = lastSample.endDate

        for sample in samples.dropLast().reversed() {
            let categoryID = classifier.classify(sample: sample, preferences: monitoringPreferences).id
            guard categoryIDs.contains(categoryID) else { break }
            guard streakStart.timeIntervalSince(sample.endDate) <= 90 else { break }

            streakStart = sample.startDate
            streakEnd = max(streakEnd, sample.endDate)
        }

        return max(0, streakEnd.timeIntervalSince(streakStart))
    }

    private func isProfileWithinSchedule(_ profile: FocusModeProfile, at date: Date) -> Bool {
        let weekday = Calendar.autoupdatingCurrent.component(.weekday, from: date)
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)

        return profile.isEnabled &&
            profile.weekdays.contains(weekday) &&
            hour >= profile.startHour &&
            hour < profile.endHour
    }

    private func activeFocusBlockMatch(at date: Date = Date()) -> FocusBlockMatch? {
        guard let currentSnapshot else { return nil }

        let normalizedDomain = classifier.domain(from: sanitizedURL(from: currentSnapshot.webURL))
        let normalizedTitle = sanitizedTitle(from: currentSnapshot.pageTitle)
        let normalizedAppName = normalizePattern(currentSnapshot.applicationName)
        let normalizedBundleID = normalizePattern(currentSnapshot.bundleIdentifier ?? "")

        for profile in focusProfiles where profile.hasBlockingRules && isProfileWithinSchedule(profile, at: date) {
            if let domain = normalizedDomain,
               let blockedDomain = profile.blockedDomains.first(where: { !$0.isEmpty && domain.contains($0) }) {
                return FocusBlockMatch(
                    profile: profile,
                    targetKind: .domain,
                    blockedPattern: blockedDomain,
                    applicationName: currentSnapshot.applicationName,
                    pageTitle: normalizedTitle,
                    domain: domain
                )
            }

            if let blockedApplication = profile.blockedApplications.first(where: { pattern in
                !pattern.isEmpty && (normalizedAppName.contains(pattern) || normalizedBundleID.contains(pattern))
            }) {
                return FocusBlockMatch(
                    profile: profile,
                    targetKind: .application,
                    blockedPattern: blockedApplication,
                    applicationName: currentSnapshot.applicationName,
                    pageTitle: normalizedTitle,
                    domain: normalizedDomain
                )
            }
        }

        return nil
    }

    private func invalidateSummaries() {
        summaryCache.removeAll()
        summaryRevision &+= 1
    }

    private func invalidateSummaries(touching sample: ActivitySample) {
        invalidateSummaries(from: sample.startDate, to: sample.endDate)
    }

    private func invalidateSummaries(from startDate: Date, to endDate: Date) {
        guard !summaryCache.isEmpty else {
            summaryRevision &+= 1
            return
        }

        let calendar = Calendar.autoupdatingCurrent
        var day = calendar.startOfDay(for: min(startDate, endDate))
        let lastDay = calendar.startOfDay(for: max(startDate, endDate))

        while day <= lastDay {
            summaryCache.removeValue(forKey: day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        summaryRevision &+= 1
    }

    private func invalidateSummariesForActivity(
        from startDate: Date,
        to endDate: Date,
        at timestamp: Date,
        coalescingLiveExtension: Bool
    ) {
        guard coalescingLiveExtension else {
            lastLiveSummaryRefreshAt = timestamp
            invalidateSummaries(from: startDate, to: endDate)
            return
        }

        if let lastLiveSummaryRefreshAt,
           timestamp.timeIntervalSince(lastLiveSummaryRefreshAt) < liveSummaryRefreshInterval {
            return
        }

        lastLiveSummaryRefreshAt = timestamp
        invalidateSummaries(from: startDate, to: endDate)
    }

    private func normalizedDay(_ day: Date) -> Date {
        Calendar.autoupdatingCurrent.startOfDay(for: day)
    }

    private func normalizePattern(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizePattern(_ value: String, for matchTarget: RuleMatchTarget) -> String {
        switch matchTarget {
        case .domain:
            return classifier.domain(from: value) ?? normalizePattern(value)
        case .applicationName, .bundleIdentifier:
            return normalizePattern(value)
        }
    }

    private func upsertRule(categoryID: String, matchTarget: RuleMatchTarget, pattern: String) {
        let cleanedPattern = normalizePattern(pattern, for: matchTarget)
        guard !cleanedPattern.isEmpty else { return }
        guard monitoringPreferences.category(for: categoryID) != nil else { return }

        if let index = monitoringPreferences.categoryRules.firstIndex(where: { rule in
            rule.matchTarget == matchTarget && rule.pattern == cleanedPattern
        }) {
            monitoringPreferences.categoryRules[index].categoryID = categoryID
            let updatedRule = monitoringPreferences.categoryRules.remove(at: index)
            monitoringPreferences.categoryRules.insert(updatedRule, at: 0)
        } else {
            monitoringPreferences.categoryRules.insert(
                CategoryRule(
                    categoryID: categoryID,
                    matchTarget: matchTarget,
                    pattern: cleanedPattern
                ),
                at: 0
            )
        }

        persistMonitoringPreferences()
    }

    private func sanitizedURL(from rawURL: String?) -> String? {
        guard let domain = classifier.domain(from: rawURL) else {
            return rawURL
        }

        if monitoringPreferences.privacySettings.storesFullURLs {
            return rawURL
        }

        return "https://\(domain)"
    }

    private func sanitizedTitle(from rawTitle: String?) -> String? {
        monitoringPreferences.privacySettings.storesPageTitles ? rawTitle : nil
    }

    private func slugify(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let characters = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let raw = String(characters)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .lowercased()
        return raw.isEmpty ? "categoria" : raw
    }

    private func uniqueCategoryID(base: String) -> String {
        var candidate = base
        var suffix = 2

        while monitoringPreferences.category(for: candidate) != nil {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }

        return candidate
    }

    private func migrateCalendarSecretsIfNeeded(snapshot: GoogleCalendarSnapshot) {
        if !snapshot.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           keychainService.string(for: Self.googleCalendarClientSecretKey) == nil {
            try? keychainService.setString(snapshot.clientSecret, for: Self.googleCalendarClientSecretKey)
        }

        for connection in googleCalendarConnections {
            if let legacyTokens = connection.legacyTokens,
               keychainService.codable(GoogleCalendarTokens.self, for: Self.googleCalendarTokenKey(connection.id)) == nil {
                try? keychainService.setCodable(legacyTokens, for: Self.googleCalendarTokenKey(connection.id))
            }

            if let tokens = loadCalendarTokens(connectionID: connection.id) {
                calendarTokensByConnectionID[connection.id] = tokens
            }
        }

        if let connectionsNeedingCleanup = googleCalendarConnections.firstIndex(where: { $0.legacyTokens != nil }) {
            for index in googleCalendarConnections.indices {
                googleCalendarConnections[index].legacyTokens = nil
            }
            _ = connectionsNeedingCleanup
            persistGoogleCalendar()
        }
    }

    private func storeCalendarTokens(_ tokens: GoogleCalendarTokens, connectionID: String) throws {
        calendarTokensByConnectionID[connectionID] = tokens
        try keychainService.setCodable(tokens, for: Self.googleCalendarTokenKey(connectionID))
    }

    private func loadCalendarTokens(connectionID: String) -> GoogleCalendarTokens? {
        if let cached = calendarTokensByConnectionID[connectionID] {
            return cached
        }

        let stored = keychainService.codable(GoogleCalendarTokens.self, for: Self.googleCalendarTokenKey(connectionID))
        if let stored {
            calendarTokensByConnectionID[connectionID] = stored
        }
        return stored
    }

    private func sortSamples() {
        samples.sort(by: Self.sampleSortOrder)
    }

    private static func sampleSortOrder(_ lhs: ActivitySample, _ rhs: ActivitySample) -> Bool {
        if lhs.startDate == rhs.startDate {
            return lhs.endDate < rhs.endDate
        }

        return lhs.startDate < rhs.startDate
    }

    private func canMerge(lhs: ActivitySample, rhs: ActivitySample) -> Bool {
        let gap = min(
            abs(lhs.startDate.timeIntervalSince(rhs.endDate)),
            abs(rhs.startDate.timeIntervalSince(lhs.endDate))
        )

        return lhs.applicationName == rhs.applicationName &&
            lhs.bundleIdentifier == rhs.bundleIdentifier &&
            lhs.webURL == rhs.webURL &&
            lhs.webDomain == rhs.webDomain &&
            lhs.pageTitle == rhs.pageTitle &&
            lhs.manualCategoryID == rhs.manualCategoryID &&
            gap <= sessionGapTolerance
    }

    private func makeTeamScore(
        trackedTime: TimeInterval,
        focusTime: TimeInterval,
        plannedTime: TimeInterval,
        contextSwitches: Int
    ) -> Int {
        let utilization = plannedTime > 0 ? min(trackedTime / plannedTime, 1.25) : 1
        let focusRatio = trackedTime > 0 ? min(focusTime / trackedTime, 1) : 0
        let switchPenalty = min(Double(contextSwitches) / 120, 0.2)
        let rawScore = (utilization * 52) + (focusRatio * 38) + ((1 - switchPenalty) * 10)
        return max(0, min(100, Int(rawScore.rounded())))
    }

    private func makeWorkspaceMemberPayload(for day: Date) -> WorkspaceMemberSnapshotPayload {
        let report = weeklyReport(containing: day)
        let plannedTime = max(report.totalTrackedTime * 0.92, report.averageDailyTrackedTime * 5)
        let score = makeTeamScore(
            trackedTime: report.totalTrackedTime,
            focusTime: report.focusTime,
            plannedTime: plannedTime,
            contextSwitches: report.contextSwitches
        )

        return WorkspaceMemberSnapshotPayload(
            organizationName: teamSettings.organizationName,
            memberDisplayName: teamSettings.memberDisplayName,
            roleLabel: teamSettings.roleLabel,
            trackedTime: report.totalTrackedTime,
            focusTime: report.focusTime,
            plannedTime: plannedTime,
            contextSwitches: report.contextSwitches,
            score: score,
            snapshotDay: Calendar.autoupdatingCurrent.startOfDay(for: day),
            weekStart: report.startDate,
            weekEnd: report.endDate
        )
    }

    private func sendZapierFocusEventIfNeeded(type: String, profileTitle: String, details: [String: String]) async {
        guard zapierSettings.isEnabled,
              zapierSettings.sendsFocusEvents,
              zapierConfigured
        else { return }

        var payloadDetails = details
        payloadDetails["profile"] = profileTitle
        await sendZapierEvent(type: type, details: payloadDetails)
    }

    private func sendZapierCalendarSyncEventIfNeeded(source: String, itemCount: Int) async {
        guard zapierSettings.isEnabled,
              zapierSettings.sendsCalendarSyncEvents,
              zapierConfigured
        else { return }

        await sendZapierEvent(
            type: "calendar_sync",
            details: [
                "source": source,
                "items": String(itemCount),
            ]
        )
    }

    private func sendZapierWorkspaceEventIfNeeded(memberCount: Int) async {
        guard zapierSettings.isEnabled,
              zapierSettings.sendsWorkspaceRankingEvents,
              zapierConfigured
        else { return }

        await sendZapierEvent(
            type: "workspace_ranking_sync",
            details: [
                "workspace": teamSettings.workspaceID,
                "members": String(memberCount),
            ]
        )
    }

    private func sendZapierEvent(type: String, details: [String: String]) async {
        guard canUse(.advancedIntegrations) else {
            zapierStatusMessage = lockMessage(for: .advancedIntegrations)
            return
        }

        do {
            let payload = ZapierWebhookPayload(
                eventType: type,
                sentAt: Date(),
                appName: "luum",
                organizationName: teamSettings.organizationName,
                memberName: teamSettings.memberDisplayName,
                details: details
            )
            try await zapierService.send(
                webhookURL: zapierSettings.webhookURL,
                payload: payload
            )
            monitoringPreferences.zapierSettings.lastDeliveryAt = Date()
            zapierStatusMessage = "Webhook do Zapier entregue com sucesso."
            persistMonitoringPreferences()
        } catch {
            zapierStatusMessage = error.localizedDescription
        }
    }

    private var workspaceSecret: String? {
        keychainService.string(for: Self.teamWorkspaceSecretKey)
    }

    private static let firebaseAuthSessionKey = "firebase-auth-session"
    private static let firebaseAuthRequestKey = "firebase-auth-request"
    private static let googleCalendarClientSecretKey = "google-calendar-client-secret"
    private static let notionCalendarTokenKey = "notion-calendar-token"
    private static let outlookCalendarTokenKey = "outlook-calendar-token"
    private static let clickUpTokenKey = "clickup-api-token"
    private static let linearTokenKey = "linear-api-key"
    private static let aiClassificationAPIKeyKey = "ai-classification-api-key"
    private static let teamWorkspaceSecretKey = "team-workspace-secret"

    private static func googleCalendarTokenKey(_ connectionID: String) -> String {
        "google-calendar-token-\(connectionID)"
    }
}

private struct AggregateBucket {
    let label: String
    let secondaryLabel: String?
    let systemImage: String
    var duration: TimeInterval = 0
    var categoryTotals: [ActivityCategory: TimeInterval] = [:]

    var item: UsageBreakdownItem {
        UsageBreakdownItem(
            id: label,
            label: label,
            secondaryLabel: secondaryLabel,
            duration: duration,
            category: categoryTotals.max(by: { $0.value < $1.value })?.key,
            systemImage: systemImage
        )
    }
}

private struct WeeklyExportBreakdown: Codable {
    let label: String
    let duration: TimeInterval
}

private struct WeeklyReportExportPayload: Codable {
    let startDate: Date
    let endDate: Date
    let totalTrackedTime: TimeInterval
    let averageDailyTrackedTime: TimeInterval
    let contextSwitches: Int
    let focusTime: TimeInterval
    let distractionTime: TimeInterval
    let topCategories: [WeeklyExportBreakdown]
    let topApps: [WeeklyExportBreakdown]
    let topSites: [WeeklyExportBreakdown]
    let highlights: [String]
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
