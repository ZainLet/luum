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

    private(set) var monitoringPreferences: MonitoringPreferencesSnapshot

    var googleCalendarClientID: String
    var googleCalendarClientSecret: String
    private(set) var googleCalendarConnections: [GoogleCalendarConnectionSnapshot]
    private(set) var googleCalendarStatusMessage: String?
    private(set) var isConnectingGoogleCalendar = false
    private(set) var isSyncingGoogleCalendar = false

    private(set) var cloudSyncStatusMessage: String?
    private(set) var cloudSyncLastSyncAt: Date?
    private(set) var isSyncingCloud = false

    let classifier = ClassificationEngine()

    @ObservationIgnored private let persistence: ActivityPersistence
    @ObservationIgnored private let monitor: ActivityMonitor
    @ObservationIgnored private let googleCalendarPersistence: GoogleCalendarPersistence
    @ObservationIgnored private let googleCalendarService: GoogleCalendarService
    @ObservationIgnored private let monitoringPreferencesPersistence: MonitoringPreferencesPersistence
    @ObservationIgnored private let reminderEngine: ReminderEngine
    @ObservationIgnored private let keychainService: KeychainService
    @ObservationIgnored private let cloudSyncService: CloudSyncService
    @ObservationIgnored private let sessionGapTolerance: TimeInterval = 15
    @ObservationIgnored private var calendarTokensByConnectionID: [String: GoogleCalendarTokens] = [:]
    @ObservationIgnored private var summaryCache: [Date: DailySummary] = [:]
    @ObservationIgnored private var persistTask: Task<Void, Never>?
    @ObservationIgnored private var cloudSyncTask: Task<Void, Never>?
    @ObservationIgnored private var maintenanceTask: Task<Void, Never>?
    @ObservationIgnored private let calendarRefreshInterval: TimeInterval = 900
    @ObservationIgnored private let cloudSyncInterval: TimeInterval = 900

    init(
        persistence: ActivityPersistence = ActivityPersistence(),
        monitor: ActivityMonitor? = nil,
        googleCalendarPersistence: GoogleCalendarPersistence = GoogleCalendarPersistence(),
        googleCalendarService: GoogleCalendarService = GoogleCalendarService(),
        monitoringPreferencesPersistence: MonitoringPreferencesPersistence = MonitoringPreferencesPersistence(),
        reminderEngine: ReminderEngine = ReminderEngine(),
        keychainService: KeychainService = KeychainService(),
        cloudSyncService: CloudSyncService = CloudSyncService()
    ) {
        self.persistence = persistence
        self.monitor = monitor ?? ActivityMonitor()
        self.googleCalendarPersistence = googleCalendarPersistence
        self.googleCalendarService = googleCalendarService
        self.monitoringPreferencesPersistence = monitoringPreferencesPersistence
        self.reminderEngine = reminderEngine
        self.keychainService = keychainService
        self.cloudSyncService = cloudSyncService

        let monitoringPreferences = monitoringPreferencesPersistence.load().normalized()
        let calendarSnapshot = googleCalendarPersistence.load()

        self.monitoringPreferences = monitoringPreferences
        self.samples = persistence.load(retentionDays: monitoringPreferences.privacySettings.retentionDays)
        self.googleCalendarClientID = calendarSnapshot.clientID
        self.googleCalendarClientSecret = keychainService.string(for: Self.googleCalendarClientSecretKey) ?? calendarSnapshot.clientSecret
        self.googleCalendarConnections = calendarSnapshot.connections
        self.googleCalendarStatusMessage = googleCalendarConnections.isEmpty ? nil : "Google Agenda pronta para sincronizar."
        self.cloudSyncStatusMessage = nil

        migrateCalendarSecretsIfNeeded(snapshot: calendarSnapshot)

        self.monitor.onSnapshot = { [weak self] snapshot in
            self?.ingest(snapshot)
        }
        self.monitor.onInactivity = { [weak self] timestamp in
            self?.closeCurrentSession(at: timestamp)
        }
        self.monitor.onAutomationMessage = { [weak self] message in
            self?.automationStatusMessage = message
        }
        self.monitor.onInputMonitoringMessage = { [weak self] message in
            self?.inputMonitoringMessage = message
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

    var categoryRules: [CategoryRule] {
        monitoringPreferences.categoryRules
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

    var privacySettings: PrivacySettings {
        monitoringPreferences.privacySettings
    }

    var cloudSyncSettings: CloudSyncSettings {
        monitoringPreferences.cloudSyncSettings
    }

    var rulePreviews: [RulePreview] {
        classifier.previewRules(from: monitoringPreferences)
    }

    var trackedAppsCount: Int {
        Set(samples.filter { !$0.isHidden && !isIgnored(sample: $0) }.map(\.applicationName)).count
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

    var currentActivityTitle: String {
        guard let currentSnapshot else {
            return "Nenhuma atividade ativa agora"
        }

        if let domain = classifier.domain(from: currentSnapshot.webURL) {
            return "\(currentSnapshot.applicationName) em \(domain)"
        }

        return currentSnapshot.applicationName
    }

    var isGoogleCalendarConfigured: Bool {
        !googleCalendarClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    var cloudSyncConfigured: Bool {
        !cloudSyncSettings.endpointURL.isEmpty &&
        !cloudSyncSettings.backupID.isEmpty &&
        !(cloudBackupSecret?.isEmpty ?? true)
    }

    var hasCloudBackupSecret: Bool {
        !(cloudBackupSecret?.isEmpty ?? true)
    }

    func bootstrap(selectedDay: Date = Date()) {
        startMonitoring()
        startMaintenanceLoop()

        Task { [weak self] in
            await self?.ensureAgenda(for: selectedDay)
            await self?.reminderEngine.refreshAuthorizationStatus()
        }
    }

    func startMonitoring() {
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

    func refreshGoogleCalendar(for day: Date = Date()) {
        guard !isConnectingGoogleCalendar, !isSyncingGoogleCalendar else { return }

        Task { [weak self] in
            await self?.runCalendarSync(for: day, force: true)
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
        monitoringPreferences.cloudSyncSettings.isEnabled = value
        persistMonitoringPreferences()
        if value {
            scheduleCloudSyncIfNeeded(reason: "cloud-enabled")
        } else {
            cloudSyncTask?.cancel()
        }
    }

    func updateCloudSyncEndpointURL(_ value: String) {
        monitoringPreferences.cloudSyncSettings.endpointURL = value
        persistMonitoringPreferences()
    }

    func updateCloudSyncBackupID(_ value: String) {
        monitoringPreferences.cloudSyncSettings.backupID = value
        persistMonitoringPreferences()
    }

    func updateCloudSyncSyncRawActivities(_ value: Bool) {
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

    func updateCloudBackupSecret(_ value: String) {
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.cloudBackupSecretKey)
            } else {
                try keychainService.setString(value, for: Self.cloudBackupSecretKey)
            }
            cloudSyncStatusMessage = "Chave de backup atualizada neste Mac."
        } catch {
            cloudSyncStatusMessage = error.localizedDescription
        }
    }

    func syncCloudBackupNow() {
        guard !isSyncingCloud else { return }
        Task { [weak self] in
            await self?.runCloudSync()
        }
    }

    func restoreCloudBackup() {
        guard !isSyncingCloud else { return }
        Task { [weak self] in
            await self?.runCloudRestore()
        }
    }

    func category(for id: String) -> ActivityCategory? {
        monitoringPreferences.category(for: id)
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
        let cleanedPattern = normalizePattern(pattern, for: matchTarget)
        guard !cleanedPattern.isEmpty else { return }
        guard monitoringPreferences.category(for: categoryID) != nil else { return }

        monitoringPreferences.categoryRules.insert(
            CategoryRule(
                categoryID: categoryID,
                matchTarget: matchTarget,
                pattern: cleanedPattern
            ),
            at: 0
        )
        persistMonitoringPreferences()
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard monitoringPreferences.category(for: categoryID) != nil else { return }

        monitoringPreferences.reminderProfiles.append(
            ReminderProfile(
                title: trimmedTitle,
                categoryID: categoryID,
                thresholdMinutes: max(5, thresholdMinutes),
                weekdays: weekdays.sorted(),
                isEnabled: true,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "O luum percebeu uma sequencia longa dessa categoria."
                    : message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        persistMonitoringPreferences()
    }

    func updateReminder(_ reminder: ReminderProfile) {
        guard let index = monitoringPreferences.reminderProfiles.firstIndex(where: { $0.id == reminder.id }) else { return }
        monitoringPreferences.reminderProfiles[index] = reminder
        persistMonitoringPreferences()
    }

    func removeReminder(id: UUID) {
        monitoringPreferences.reminderProfiles.removeAll { $0.id == id }
        persistMonitoringPreferences()
    }

    func overrideActivityCategory(sampleID: UUID, categoryID: String?) {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return }
        guard categoryID == nil || monitoringPreferences.category(for: categoryID!) != nil else { return }
        samples[index].manualCategoryID = categoryID
        invalidateSummaries()
        schedulePersistence()
        evaluateReminders()
    }

    func setActivityHidden(sampleID: UUID, isHidden: Bool) {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return }
        samples[index].isHidden = isHidden
        invalidateSummaries()
        schedulePersistence()
        evaluateReminders()
    }

    func resetActivityEdits(sampleID: UUID) {
        guard let index = samples.firstIndex(where: { $0.id == sampleID }) else { return }
        samples[index].manualCategoryID = nil
        samples[index].isHidden = false
        samples[index].note = nil
        invalidateSummaries()
        schedulePersistence()
        evaluateReminders()
    }

    func ensureAgenda(for day: Date) async {
        await runCalendarSync(for: day, force: false)
    }

    func agendaSummary(for day: Date) -> AgendaSummary {
        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let enabledConnections = googleCalendarConnections.filter(\.isEnabled)
        let events: [CalendarAgendaItem] = enabledConnections.flatMap { connection in
            let storedDay = connection.agendaDay.map { Calendar.autoupdatingCurrent.startOfDay(for: $0) }
            guard storedDay == normalizedDay else { return [CalendarAgendaItem]() }
            return connection.agendaItems
        }
        .sorted(by: { $0.startDate < $1.startDate })

        let lastSyncAt = enabledConnections.compactMap(\.lastSyncAt).max()

        return AgendaSummary(
            day: day,
            events: events,
            isConnected: !enabledConnections.isEmpty,
            isConfigured: isGoogleCalendarConfigured,
            lastSyncAt: lastSyncAt,
            connections: enabledConnections.map {
                GoogleCalendarConnectionSummary(
                    id: $0.id,
                    profile: $0.profile,
                    calendars: $0.calendars,
                    isEnabled: $0.isEnabled,
                    lastSyncAt: $0.lastSyncAt
                )
            }
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

        var categoryTotals: [ActivityCategory: TimeInterval] = [:]
        var appBuckets: [String: AggregateBucket] = [:]
        var websiteBuckets: [String: AggregateBucket] = [:]
        var resolvedActivities: [ResolvedActivitySample] = []

        for sample in samples {
            guard !sample.isHidden else { continue }
            guard !isIgnored(sample: sample) else { continue }
            guard let clipped = clip(sample: sample, from: dayStart, to: dayEnd) else { continue }

            let category = classifier.classify(sample: clipped, preferences: monitoringPreferences)
            categoryTotals[category, default: 0] += clipped.duration

            var appBucket = appBuckets[clipped.applicationName, default: AggregateBucket(
                label: clipped.applicationName,
                secondaryLabel: clipped.bundleIdentifier,
                systemImage: "app.connected.to.app.below.fill"
            )]
            appBucket.duration += clipped.duration
            appBucket.categoryTotals[category, default: 0] += clipped.duration
            appBuckets[clipped.applicationName] = appBucket

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
            .sorted { $0.startDate < $1.startDate }

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

    private func runCalendarConnect(for day: Date) async {
        let clientID = googleCalendarClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = googleCalendarClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clientID.isEmpty else {
            googleCalendarStatusMessage = GoogleCalendarIssue.missingClientID.errorDescription
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

    private func runCalendarSync(for day: Date, force: Bool) async {
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
    }

    private func runCloudSync() async {
        guard monitoringPreferences.cloudSyncSettings.isEnabled else { return }
        guard cloudSyncConfigured else {
            cloudSyncStatusMessage = "Preencha endpoint, Backup ID e chave para ativar o sync."
            return
        }
        guard let secret = cloudBackupSecret else {
            cloudSyncStatusMessage = "A chave de backup nao foi encontrada neste Mac."
            return
        }

        isSyncingCloud = true
        defer { isSyncingCloud = false }

        do {
            let updatedAt = try await cloudSyncService.push(
                baseURL: monitoringPreferences.cloudSyncSettings.endpointURL,
                backupID: monitoringPreferences.cloudSyncSettings.backupID,
                secret: secret,
                payload: makeCloudBackupPayload()
            )
            cloudSyncLastSyncAt = updatedAt
            cloudSyncStatusMessage = "Backup sincronizado com sucesso."
        } catch {
            cloudSyncStatusMessage = error.localizedDescription
        }
    }

    private func runCloudRestore() async {
        guard cloudSyncConfigured else {
            cloudSyncStatusMessage = "Configure o sync antes de restaurar."
            return
        }
        guard let secret = cloudBackupSecret else {
            cloudSyncStatusMessage = "A chave de backup nao foi encontrada neste Mac."
            return
        }

        isSyncingCloud = true
        defer { isSyncingCloud = false }

        do {
            guard let payload = try await cloudSyncService.pull(
                baseURL: monitoringPreferences.cloudSyncSettings.endpointURL,
                backupID: monitoringPreferences.cloudSyncSettings.backupID,
                secret: secret
            ) else {
                cloudSyncStatusMessage = "Nenhum backup encontrado para esse identificador."
                return
            }

            monitoringPreferences = mergeRestoredMonitoringPreferences(payload.monitoringPreferences)
            googleCalendarClientID = payload.googleCalendarSnapshot.clientID
            googleCalendarConnections = payload.googleCalendarSnapshot.connections
            if let rawActivities = payload.rawActivities {
                samples = rawActivities
            }

            if !googleCalendarConnections.isEmpty {
                googleCalendarStatusMessage = "Estrutura da agenda restaurada. Se este Mac ainda nao tiver os tokens locais, reconecte as contas Google."
            }

            persistMonitoringPreferences()
            persistGoogleCalendar()
            schedulePersistence()
            invalidateSummaries()
            cloudSyncStatusMessage = "Backup restaurado com sucesso."
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
        if monitoringPreferences.cloudSyncSettings.syncRawActivities {
            rawActivities = samples.map(makeCloudSafeSample)
        } else {
            rawActivities = nil
        }

        return CloudBackupPayload(
            schemaVersion: 1,
            exportedAt: Date(),
            deviceName: Host.current().localizedName ?? "Mac",
            monitoringPreferences: monitoringPreferences,
            googleCalendarSnapshot: GoogleCalendarSnapshot(
                clientID: googleCalendarClientID,
                clientSecret: "",
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

        do {
            try monitoringPreferencesPersistence.save(snapshot: monitoringPreferences)
        } catch {
            automationStatusMessage = "Nao foi possivel salvar as preferencias de monitoramento."
        }

        reconcileCurrentSnapshotAfterPreferencesChange()
        scheduleCloudSyncIfNeeded(reason: "preferences")
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
            closeCurrentSession(at: snapshot.timestamp)
            return
        }

        currentSnapshot = snapshot

        if let lastIndex = samples.indices.last,
           samples[lastIndex].canExtend(with: snapshot, maximumGap: sessionGapTolerance, sanitizedURL: sanitizedURL, sanitizedTitle: sanitizedTitle) {
            samples[lastIndex].endDate = snapshot.timestamp
            samples[lastIndex].webURL = sanitizedURL
            samples[lastIndex].webDomain = domain
            samples[lastIndex].pageTitle = sanitizedTitle
        } else {
            if let lastIndex = samples.indices.last, snapshot.timestamp.timeIntervalSince(samples[lastIndex].endDate) <= sessionGapTolerance {
                samples[lastIndex].endDate = max(samples[lastIndex].endDate, snapshot.timestamp)
            }

            samples.append(ActivitySample(snapshot: snapshot, domain: domain, sanitizedURL: sanitizedURL, sanitizedTitle: sanitizedTitle))
        }

        invalidateSummaries()
        schedulePersistence()
        evaluateReminders()
    }

    private func closeCurrentSession(at timestamp: Date) {
        guard currentSnapshot != nil || !samples.isEmpty else { return }

        if let lastIndex = samples.indices.last, timestamp.timeIntervalSince(samples[lastIndex].endDate) <= sessionGapTolerance {
            samples[lastIndex].endDate = max(samples[lastIndex].endDate, timestamp)
        }

        currentSnapshot = nil
        schedulePersistence()
    }

    private func schedulePersistence() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.flushPersistence()
        }

        scheduleCloudSyncIfNeeded(reason: "activity")
    }

    private func flushPersistence() {
        samples = persistence.trim(samples: samples, retentionDays: monitoringPreferences.privacySettings.retentionDays)

        do {
            try persistence.save(samples: samples, retentionDays: monitoringPreferences.privacySettings.retentionDays)
        } catch {
            automationStatusMessage = "Nao foi possivel salvar o historico local do luum."
        }
    }

    private func scheduleCloudSyncIfNeeded(reason _: String) {
        guard monitoringPreferences.cloudSyncSettings.isEnabled else { return }
        guard cloudSyncConfigured else { return }

        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            await self?.runCloudSync()
        }
    }

    private func startMaintenanceLoop() {
        guard maintenanceTask == nil else { return }

        maintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
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

    private func evaluateReminders() {
        let filteredSamples = samples.filter { !$0.isHidden && !isIgnored(sample: $0) }
        Task { [weak self] in
            guard let self else { return }
            await self.reminderEngine.evaluate(
                samples: filteredSamples,
                preferences: self.monitoringPreferences,
                classifier: self.classifier
            )
        }
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

    private func invalidateSummaries() {
        summaryCache.removeAll()
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

    private var cloudBackupSecret: String? {
        keychainService.string(for: Self.cloudBackupSecretKey)
    }

    private static let googleCalendarClientSecretKey = "google-calendar-client-secret"
    private static let cloudBackupSecretKey = "cloud-sync-backup-secret"

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
