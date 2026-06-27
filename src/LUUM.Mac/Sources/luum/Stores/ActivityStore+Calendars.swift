import AppKit
import Foundation

extension ActivityStore {
    // MARK: - Notion Calendar

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

    func connectNotionCalendar() {
        Task { await runNotionConnect() }
    }

    func disconnectNotionCalendar() {
        keychainService.removeValue(for: Self.notionCalendarTokenKey)
        monitoringPreferences.notionCalendarSettings.isEnabled = false
        notionAgendaItems = []
        notionAgendaDay = nil
        notionCalendarStatusMessage = "Notion desconectado."
        persistMonitoringPreferences()
    }

    func refreshNotionCalendar(for day: Date = Date()) {
        guard !isSyncingNotionCalendar else { return }
        Task { [weak self] in
            await self?.runNotionCalendarSync(for: day, force: true)
        }
    }

    func runNotionConnect() async {
        guard canUse(.advancedIntegrations) else {
            notionCalendarStatusMessage = lockMessage(for: .advancedIntegrations)
            return
        }
        guard let verified = try? await authCoordinator.verifiedAuthSessionForProtectedRequest() else {
            notionCalendarStatusMessage = "Entre na sua conta Luum antes de conectar o Notion."
            return
        }
        notionCalendarStatusMessage = "Carregando autorização do Notion..."

        let backendURL = FirebaseAuthService.defaultBaseURL
        guard let url = URL(string: "\(backendURL)/api/integrations?action=notion-auth") else {
            notionCalendarStatusMessage = "Erro ao montar URL de autenticação do Notion."
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(verified.idToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            guard (200 ..< 300).contains(statusCode) else {
                struct ErrorBody: Decodable { let error: String }
                let msg = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "Noção não configurada no servidor."
                notionCalendarStatusMessage = msg
                return
            }
            struct AuthResponse: Decodable { let url: String }
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard let authURL = URL(string: authResponse.url) else {
                notionCalendarStatusMessage = "URL OAuth do Notion inválida."
                return
            }
            NSWorkspace.shared.open(authURL)
            notionCalendarStatusMessage = "Autorizando no Notion... Conclua no navegador e volte ao Luum."
        } catch {
            notionCalendarStatusMessage = "Erro ao iniciar conexão com Notion."
        }
    }

    func handleNotionOAuthCallback(_ url: URL) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        if let error = items.first(where: { $0.name == "error" })?.value {
            notionCalendarStatusMessage = humanReadableOAuthError(error, integration: "Notion")
            return
        }

        guard let accessToken = items.first(where: { $0.name == "access_token" })?.value,
              !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notionCalendarStatusMessage = "Token do Notion não recebido. Tente reconectar."
            return
        }

        let rawName = items.first(where: { $0.name == "workspace_name" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let workspaceName = rawName.isEmpty ? "Notion" : rawName

        do {
            try keychainService.setString(accessToken, for: Self.notionCalendarTokenKey)
            monitoringPreferences.notionCalendarSettings.isEnabled = true
            if monitoringPreferences.notionCalendarSettings.workspaceLabel == NotionCalendarSettings.default.workspaceLabel {
                monitoringPreferences.notionCalendarSettings.workspaceLabel = workspaceName
            }
            notionCalendarStatusMessage = "Notion conectado: \(workspaceName). Configure as fontes de data abaixo."
            persistMonitoringPreferences()
        } catch {
            notionCalendarStatusMessage = "Erro ao salvar token do Notion no Keychain."
        }
    }

    func runNotionCalendarSync(for day: Date, force: Bool) async {
        guard canUse(.advancedIntegrations) else {
            if force {
                notionCalendarStatusMessage = lockMessage(for: .advancedIntegrations)
            }
            return
        }

        let settings = notionCalendarSettings.normalized()

        guard settings.isEnabled else {
            if force {
                notionCalendarStatusMessage = "Ative a integração do Notion para sincronizar esta fonte."
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

    // MARK: - Outlook Calendar

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

    func connectOutlookCalendar() {
        Task { await runOutlookConnect() }
    }

    func disconnectOutlookCalendar() {
        keychainService.removeValue(for: Self.outlookCalendarSessionKey)
        keychainService.removeValue(for: Self.outlookCalendarTokenKey)
        monitoringPreferences.outlookCalendarSettings.isEnabled = false
        monitoringPreferences.outlookCalendarSettings.accountEmail = ""
        monitoringPreferences.outlookCalendarSettings.calendars = []
        outlookAgendaItems = []
        outlookAgendaDay = nil
        outlookCalendarStatusMessage = "Outlook desconectado."
        persistMonitoringPreferences()
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

    func runOutlookConnect() async {
        guard canUse(.agendaIntegrations) else {
            outlookCalendarStatusMessage = lockMessage(for: .agendaIntegrations)
            return
        }
        guard let verified = try? await authCoordinator.verifiedAuthSessionForProtectedRequest() else {
            outlookCalendarStatusMessage = "Entre na sua conta Luum antes de conectar o Outlook."
            return
        }
        outlookCalendarStatusMessage = "Carregando autorização do Outlook..."

        let backendURL = FirebaseAuthService.defaultBaseURL
        guard let url = URL(string: "\(backendURL)/api/integrations?action=outlook-auth") else {
            outlookCalendarStatusMessage = "Erro ao montar URL de autenticação do Outlook."
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(verified.idToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            guard (200 ..< 300).contains(statusCode) else {
                struct ErrorBody: Decodable { let error: String }
                let msg = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "Outlook não configurado no servidor."
                outlookCalendarStatusMessage = msg
                return
            }
            struct AuthResponse: Decodable { let url: String }
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard let authURL = URL(string: authResponse.url) else {
                outlookCalendarStatusMessage = "URL OAuth do Outlook inválida."
                return
            }
            NSWorkspace.shared.open(authURL)
            outlookCalendarStatusMessage = "Autorizando no Outlook... Conclua no navegador e volte ao Luum."
        } catch {
            outlookCalendarStatusMessage = "Erro ao iniciar conexão com Outlook."
        }
    }

    func handleOutlookOAuthCallback(_ url: URL) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        if let error = items.first(where: { $0.name == "error" })?.value {
            outlookCalendarStatusMessage = humanReadableOAuthError(error, integration: "Outlook")
            return
        }

        guard let accessToken = items.first(where: { $0.name == "access_token" })?.value,
              !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            outlookCalendarStatusMessage = "Token do Outlook não recebido. Tente reconectar."
            return
        }

        let refreshToken = items.first(where: { $0.name == "refresh_token" })?.value
        let expiresIn = TimeInterval(items.first(where: { $0.name == "expires_in" })?.value ?? "3600") ?? 3600
        let tokens = OutlookCalendarTokens.make(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)

        do {
            try keychainService.setCodable(tokens, for: Self.outlookCalendarSessionKey)
            monitoringPreferences.outlookCalendarSettings.isEnabled = true
            outlookCalendarStatusMessage = "Outlook conectado. Sincronizando calendários..."
            persistMonitoringPreferences()
            refreshOutlookCalendar()
        } catch {
            outlookCalendarStatusMessage = "Erro ao salvar token do Outlook no Keychain."
        }
    }

    func loadValidOutlookTokens() async -> OutlookCalendarTokens? {
        guard var tokens = keychainService.codable(OutlookCalendarTokens.self, for: Self.outlookCalendarSessionKey) else {
            return nil
        }

        guard tokens.isExpired else { return tokens }
        guard let refreshToken = tokens.refreshToken else {
            outlookCalendarStatusMessage = "Token Microsoft expirado. Reconecte o Outlook."
            return nil
        }

        guard let verified = try? await authCoordinator.verifiedAuthSessionForProtectedRequest() else {
            return nil
        }

        let backendURL = FirebaseAuthService.defaultBaseURL
        guard let url = URL(string: "\(backendURL)/api/integrations?action=outlook-refresh") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(verified.idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(["refresh_token": refreshToken])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                outlookCalendarStatusMessage = "Token Microsoft expirado. Reconecte o Outlook."
                return nil
            }
            struct RefreshResponse: Decodable {
                let access_token: String
                let refresh_token: String?
                let expires_in: TimeInterval
            }
            let refreshed = try JSONDecoder().decode(RefreshResponse.self, from: data)
            tokens = OutlookCalendarTokens.make(
                accessToken: refreshed.access_token,
                refreshToken: refreshed.refresh_token ?? refreshToken,
                expiresIn: refreshed.expires_in
            )
            try? keychainService.setCodable(tokens, for: Self.outlookCalendarSessionKey)
            return tokens
        } catch {
            return nil
        }
    }

    func runOutlookCalendarSync(for day: Date, force: Bool) async {
        guard canUse(.agendaIntegrations) else {
            if force {
                outlookCalendarStatusMessage = lockMessage(for: .agendaIntegrations)
            }
            return
        }

        let settings = outlookCalendarSettings.normalized()

        guard settings.isEnabled else {
            if force {
                outlookCalendarStatusMessage = "Ative a integração do Outlook para sincronizar esta fonte."
            }
            return
        }

        guard outlookCalendarConfigured else {
            if force {
                outlookCalendarStatusMessage = Self.outlookPendingConnectionMessage
            }
            return
        }

        guard let tokens = await loadValidOutlookTokens() else {
            if outlookCalendarStatusMessage == nil {
                outlookCalendarStatusMessage = OutlookCalendarIssue.missingToken.errorDescription
            }
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
                accessToken: tokens.accessToken
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
}
