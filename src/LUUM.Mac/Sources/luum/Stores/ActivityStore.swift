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

    var googleCalendarClientID: String
    var googleCalendarClientSecret: String
    private(set) var googleCalendarProfile: GoogleCalendarProfile?
    private(set) var googleCalendarAgendaItems: [CalendarAgendaItem]
    private(set) var googleCalendarAgendaDay: Date?
    private(set) var googleCalendarStatusMessage: String?
    private(set) var googleCalendarLastSyncAt: Date?
    private(set) var isConnectingGoogleCalendar = false
    private(set) var isSyncingGoogleCalendar = false

    let classifier = ClassificationEngine()

    @ObservationIgnored private var googleCalendarTokens: GoogleCalendarTokens?
    @ObservationIgnored private let persistence: ActivityPersistence
    @ObservationIgnored private let monitor: ActivityMonitor
    @ObservationIgnored private let googleCalendarPersistence: GoogleCalendarPersistence
    @ObservationIgnored private let googleCalendarService: GoogleCalendarService
    @ObservationIgnored private let sessionGapTolerance: TimeInterval = 15

    init(
        persistence: ActivityPersistence = ActivityPersistence(),
        monitor: ActivityMonitor? = nil,
        googleCalendarPersistence: GoogleCalendarPersistence = GoogleCalendarPersistence(),
        googleCalendarService: GoogleCalendarService = GoogleCalendarService()
    ) {
        let calendarSnapshot = googleCalendarPersistence.load()

        self.persistence = persistence
        self.samples = persistence.load()
        self.monitor = monitor ?? ActivityMonitor()
        self.googleCalendarPersistence = googleCalendarPersistence
        self.googleCalendarService = googleCalendarService
        self.googleCalendarClientID = calendarSnapshot.clientID
        self.googleCalendarClientSecret = calendarSnapshot.clientSecret
        self.googleCalendarTokens = calendarSnapshot.tokens
        self.googleCalendarProfile = calendarSnapshot.profile
        self.googleCalendarAgendaItems = calendarSnapshot.agendaItems
        self.googleCalendarAgendaDay = calendarSnapshot.agendaDay
        self.googleCalendarLastSyncAt = calendarSnapshot.lastSyncAt
        self.googleCalendarStatusMessage = calendarSnapshot.tokens == nil ? nil : "Google Agenda pronta para sincronizar."

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
    }

    var rulePreviews: [RulePreview] {
        classifier.previewRules
    }

    var trackedAppsCount: Int {
        Set(samples.map(\.applicationName)).count
    }

    var trackedSitesCount: Int {
        Set(samples.compactMap(\.webDomain)).count
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
        googleCalendarTokens != nil
    }

    var googleCalendarAccountLabel: String {
        googleCalendarProfile?.name ?? "Google Agenda"
    }

    var googleCalendarIdentityLine: String {
        googleCalendarProfile?.email ?? "Conecte sua agenda para cruzar compromissos com o tempo capturado."
    }

    func bootstrap(selectedDay: Date = Date()) {
        startMonitoring()

        Task { [weak self] in
            await self?.ensureAgenda(for: selectedDay)
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
        isMonitoring = false
    }

    func toggleMonitoring() {
        isMonitoring ? stopMonitoring() : startMonitoring()
    }

    func requestInputMonitoringAccess() {
        monitor.requestInputMonitoringAccess()
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

    func disconnectGoogleCalendar() {
        googleCalendarTokens = nil
        googleCalendarProfile = nil
        googleCalendarAgendaItems = []
        googleCalendarAgendaDay = nil
        googleCalendarLastSyncAt = nil
        googleCalendarStatusMessage = "Google Agenda desconectada deste Mac."
        persistGoogleCalendar()
    }

    func updateGoogleCalendarClientID(_ value: String) {
        googleCalendarClientID = value
        persistGoogleCalendar()
    }

    func updateGoogleCalendarClientSecret(_ value: String) {
        googleCalendarClientSecret = value
        persistGoogleCalendar()
    }

    func ensureAgenda(for day: Date) async {
        await runCalendarSync(for: day, force: false)
    }

    func agendaSummary(for day: Date) -> AgendaSummary {
        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let storedDay = googleCalendarAgendaDay.map { Calendar.autoupdatingCurrent.startOfDay(for: $0) }
        let events = storedDay == normalizedDay ? googleCalendarAgendaItems.sorted { $0.startDate < $1.startDate } : []

        return AgendaSummary(
            day: day,
            events: events,
            isConnected: isGoogleCalendarConnected,
            isConfigured: isGoogleCalendarConfigured,
            lastSyncAt: googleCalendarLastSyncAt,
            profile: googleCalendarProfile
        )
    }

    func summary(for day: Date) -> DailySummary {
        let calendar = Calendar.autoupdatingCurrent
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        var categoryTotals: [ActivityCategory: TimeInterval] = [:]
        var appBuckets: [String: AggregateBucket] = [:]
        var websiteBuckets: [String: AggregateBucket] = [:]
        var clippedActivities: [ActivitySample] = []

        for sample in samples {
            guard let clipped = clip(sample: sample, from: dayStart, to: dayEnd) else {
                continue
            }

            categoryTotals[clipped.category, default: 0] += clipped.duration

            var appBucket = appBuckets[clipped.applicationName, default: AggregateBucket(
                label: clipped.applicationName,
                secondaryLabel: clipped.bundleIdentifier,
                systemImage: "app.connected.to.app.below.fill"
            )]
            appBucket.duration += clipped.duration
            appBucket.categoryTotals[clipped.category, default: 0] += clipped.duration
            appBuckets[clipped.applicationName] = appBucket

            if let domain = clipped.webDomain {
                var websiteBucket = websiteBuckets[domain, default: AggregateBucket(
                    label: domain,
                    secondaryLabel: clipped.applicationName,
                    systemImage: "globe"
                )]
                websiteBucket.duration += clipped.duration
                websiteBucket.categoryTotals[clipped.category, default: 0] += clipped.duration
                websiteBuckets[domain] = websiteBucket
            }

            clippedActivities.append(clipped)
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

        let timelineActivities = clippedActivities
            .sorted { $0.startDate < $1.startDate }

        let recentActivities = clippedActivities
            .sorted { $0.endDate > $1.endDate }
            .prefix(12)
            .map { $0 }

        let totalTrackedTime = categoryTotals.values.reduce(0, +)

        return DailySummary(
            day: day,
            totalTrackedTime: totalTrackedTime,
            categoryBreakdown: categoryBreakdown,
            appBreakdown: appBreakdown,
            websiteBreakdown: websiteBreakdown,
            timelineActivities: timelineActivities,
            recentActivities: recentActivities
        )
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
            applyCalendar(result: result, for: day)
            googleCalendarStatusMessage = "Google Agenda conectada com sucesso."
        } catch {
            googleCalendarStatusMessage = error.localizedDescription
        }
    }

    private func runCalendarSync(for day: Date, force: Bool) async {
        guard let tokens = googleCalendarTokens else {
            if force, isGoogleCalendarConfigured {
                googleCalendarStatusMessage = "Conecte sua conta Google para começar a sincronizar a agenda."
            }
            return
        }

        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let storedDay = googleCalendarAgendaDay.map { Calendar.autoupdatingCurrent.startOfDay(for: $0) }
        let shouldReuseCurrentAgenda = !force && storedDay == normalizedDay && !googleCalendarAgendaItems.isEmpty && !tokens.needsRefresh

        guard !shouldReuseCurrentAgenda else { return }

        isSyncingGoogleCalendar = true
        defer { isSyncingGoogleCalendar = false }

        do {
            let result = try await googleCalendarService.refresh(
                day: day,
                clientID: googleCalendarClientID.trimmingCharacters(in: .whitespacesAndNewlines),
                clientSecret: googleCalendarClientSecret.trimmingCharacters(in: .whitespacesAndNewlines),
                existingTokens: tokens
            )
            applyCalendar(result: result, for: day)

            if force {
                googleCalendarStatusMessage = "Agenda sincronizada."
            }
        } catch {
            googleCalendarStatusMessage = error.localizedDescription
        }
    }

    private func applyCalendar(result: GoogleCalendarSyncResult, for day: Date) {
        googleCalendarTokens = result.tokens
        googleCalendarProfile = result.profile ?? googleCalendarProfile
        googleCalendarAgendaItems = result.events.sorted { $0.startDate < $1.startDate }
        googleCalendarAgendaDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        googleCalendarLastSyncAt = result.syncedAt
        persistGoogleCalendar()
    }

    private func persistGoogleCalendar() {
        do {
            try googleCalendarPersistence.save(
                snapshot: GoogleCalendarSnapshot(
                    clientID: googleCalendarClientID,
                    clientSecret: googleCalendarClientSecret,
                    tokens: googleCalendarTokens,
                    profile: googleCalendarProfile,
                    agendaDay: googleCalendarAgendaDay,
                    agendaItems: googleCalendarAgendaItems,
                    lastSyncAt: googleCalendarLastSyncAt
                )
            )
        } catch {
            googleCalendarStatusMessage = "Nao foi possivel salvar a configuracao local da Google Agenda."
        }
    }

    private func ingest(_ snapshot: ActivitySnapshot) {
        currentSnapshot = snapshot
        let domain = classifier.domain(from: snapshot.webURL)

        if let lastIndex = samples.indices.last, samples[lastIndex].canExtend(with: snapshot, maximumGap: sessionGapTolerance) {
            samples[lastIndex].endDate = snapshot.timestamp
            samples[lastIndex].webURL = snapshot.webURL
            samples[lastIndex].webDomain = domain
            samples[lastIndex].pageTitle = snapshot.pageTitle
        } else {
            if let lastIndex = samples.indices.last, snapshot.timestamp.timeIntervalSince(samples[lastIndex].endDate) <= sessionGapTolerance {
                samples[lastIndex].endDate = max(samples[lastIndex].endDate, snapshot.timestamp)
            }

            samples.append(ActivitySample(snapshot: snapshot, domain: domain))
        }

        persist()
    }

    private func closeCurrentSession(at timestamp: Date) {
        guard currentSnapshot != nil else { return }

        if let lastIndex = samples.indices.last, timestamp.timeIntervalSince(samples[lastIndex].endDate) <= sessionGapTolerance {
            samples[lastIndex].endDate = max(samples[lastIndex].endDate, timestamp)
        }

        currentSnapshot = nil
        persist()
    }

    private func persist() {
        samples = persistence.trim(samples: samples)

        do {
            try persistence.save(samples: samples)
        } catch {
            automationStatusMessage = "Nao foi possivel salvar o historico local do luum."
        }
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
