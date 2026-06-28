import Foundation
import Observation

@MainActor
@Observable
final class CalendarCoordinator {
    unowned let store: ActivityStore

    private(set) var isConnectingGoogleCalendar = false
    private(set) var isSyncingGoogleCalendar = false

    @ObservationIgnored private let googleCalendarService: GoogleCalendarService
    @ObservationIgnored private let googleCalendarPersistence: GoogleCalendarPersistence
    @ObservationIgnored private let keychainService: KeychainService
    @ObservationIgnored private let publicIntegrationConfigService: PublicIntegrationConfigService
    @ObservationIgnored private var calendarTokensByConnectionID: [String: GoogleCalendarTokens] = [:]

    init(
        store: ActivityStore,
        googleCalendarService: GoogleCalendarService,
        googleCalendarPersistence: GoogleCalendarPersistence,
        keychainService: KeychainService,
        publicIntegrationConfigService: PublicIntegrationConfigService
    ) {
        self.store = store
        self.googleCalendarService = googleCalendarService
        self.googleCalendarPersistence = googleCalendarPersistence
        self.keychainService = keychainService
        self.publicIntegrationConfigService = publicIntegrationConfigService
    }

    // MARK: - Public API

    func connectGoogleCalendar(for day: Date) {
        guard !isConnectingGoogleCalendar else { return }

        Task { [weak self] in
            await self?.runCalendarConnect(for: day)
        }
    }

    func refreshGoogleCalendar(for day: Date) {
        guard !isConnectingGoogleCalendar, !isSyncingGoogleCalendar else { return }

        Task { [weak self] in
            await self?.runCalendarSync(for: day, force: true)
        }
    }

    func refreshIntegratedCalendars(for day: Date) {
        if store.isGoogleCalendarConnected {
            refreshGoogleCalendar(for: day)
        }

        if store.notionCalendarSettings.isEnabled {
            store.refreshNotionCalendar(for: day)
        }

        if store.outlookCalendarSettings.isEnabled {
            store.refreshOutlookCalendar(for: day)
        }

        if store.clickUpSettings.isEnabled {
            store.refreshClickUp(for: day)
        }

        if store.linearSettings.isEnabled {
            store.refreshLinear(for: day)
        }
    }

    func removeCalendarTokens(connectionID: String) {
        calendarTokensByConnectionID.removeValue(forKey: connectionID)
    }

    func removeAllCalendarTokens() {
        calendarTokensByConnectionID.removeAll()
    }

    func loadCalendarTokens(connectionID: String) -> GoogleCalendarTokens? {
        if let cached = calendarTokensByConnectionID[connectionID] {
            return cached
        }

        let stored = keychainService.codable(GoogleCalendarTokens.self, for: ActivityStore.googleCalendarTokenKey(connectionID))
        if let stored {
            calendarTokensByConnectionID[connectionID] = stored
        }
        return stored
    }

    func runCalendarSync(for day: Date, force: Bool) async {
        guard store.canUse(.agendaIntegrations) else {
            if force {
                store.googleCalendarStatusMessage = store.lockMessage(for: .agendaIntegrations)
            }
            return
        }

        let clientID = store.googleCalendarClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = store.googleCalendarClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !store.googleCalendarConnections.isEmpty else {
            if force, store.isGoogleCalendarConfigured {
                store.googleCalendarStatusMessage = "Conecte pelo menos uma conta Google para sincronizar a agenda."
            }
            return
        }

        isSyncingGoogleCalendar = true
        defer { isSyncingGoogleCalendar = false }

        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        var updatedConnections = store.googleCalendarConnections
        var syncMessages: [String] = []

        await withTaskGroup(of: (String, Result<GoogleCalendarSyncResult, Error>).self) { group in
            for connection in store.googleCalendarConnections where connection.isEnabled {
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
                    (!isToday || lastSyncAge < store.calendarRefreshInterval) &&
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

        store.googleCalendarConnections = updatedConnections
        store.persistGoogleCalendar()
        store.scheduleCloudSyncIfNeeded(reason: "calendar-sync")

        if !syncMessages.isEmpty {
            store.googleCalendarStatusMessage = syncMessages.joined(separator: "\n")
        } else if force {
            store.googleCalendarStatusMessage = "Agenda sincronizada em \(store.googleCalendarConnections.count) conta(s)."
        }

        if syncMessages.isEmpty {
            let totalEvents = store.googleCalendarConnections
                .filter(\.isEnabled)
                .flatMap(\.agendaItems)
                .count
            await store.sendZapierCalendarSyncEventIfNeeded(source: "google", itemCount: totalEvents)
        }
    }

    // MARK: - Private

    private func runCalendarConnect(for day: Date) async {
        guard store.canUse(.agendaIntegrations) else {
            store.googleCalendarStatusMessage = store.lockMessage(for: .agendaIntegrations)
            return
        }

        var clientID = store.googleCalendarClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = store.googleCalendarClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        if clientID.isEmpty {
            do {
                store.googleCalendarStatusMessage = "Carregando configuração gerenciada do Google Calendar..."
                let config = try await publicIntegrationConfigService.fetch()
                store.publicIntegrationConfig = config
                clientID = config.googleCalendar.clientID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !clientID.isEmpty {
                    store.googleCalendarClientID = clientID
                    store.persistGoogleCalendar()
                }
            } catch {
                store.googleCalendarStatusMessage = error.localizedDescription
                return
            }
        }

        guard !clientID.isEmpty else {
            store.googleCalendarStatusMessage = "Google Calendar ainda não foi configurado no admin do Luum. Configure GOOGLE_CALENDAR_CLIENT_ID uma vez para liberar conexão com um clique."
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
                store.googleCalendarStatusMessage = "Não foi possível identificar a conta Google conectada."
                return
            }

            let connectionID = store.slugify(profile.email)
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

            if let existingIndex = store.googleCalendarConnections.firstIndex(where: { $0.id == connectionID }) {
                store.googleCalendarConnections[existingIndex] = connection
            } else {
                store.googleCalendarConnections.append(connection)
                store.googleCalendarConnections.sort { $0.profile.email < $1.profile.email }
            }

            store.googleCalendarStatusMessage = "Conta \(profile.email) conectada com sucesso."
            store.persistGoogleCalendar()
            store.scheduleCloudSyncIfNeeded(reason: "calendar-connect")
        } catch {
            store.googleCalendarStatusMessage = error.localizedDescription
        }
    }

    private func storeCalendarTokens(_ tokens: GoogleCalendarTokens, connectionID: String) throws {
        calendarTokensByConnectionID[connectionID] = tokens
        try keychainService.setCodable(tokens, for: ActivityStore.googleCalendarTokenKey(connectionID))
    }
}
