import AppKit
import Foundation

extension ActivityStore {
    // MARK: - ClickUp

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
            clickUpStatusMessage = "Integração do ClickUp pausada."
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

    func connectClickUp() { isConnectingClickUp = true; Task { await runClickUpConnect() } }

    func disconnectClickUp() {
        keychainService.removeValue(for: Self.clickUpTokenKey)
        monitoringPreferences.clickUpSettings.isEnabled = false
        monitoringPreferences.clickUpSettings.listIDs = []
        clickUpAgendaItems = []; clickUpAgendaDay = nil
        clickUpStatusMessage = "ClickUp desconectado."
        persistMonitoringPreferences()
    }

    func runClickUpConnect() async {
        guard canUse(.agendaIntegrations) else {
            clickUpStatusMessage = lockMessage(for: .agendaIntegrations)
            isConnectingClickUp = false
            return
        }
        guard let idToken = authSession?.idToken, !idToken.isEmpty else {
            clickUpStatusMessage = "Faça login antes de conectar o ClickUp."
            isConnectingClickUp = false
            return
        }
        clickUpStatusMessage = "Abrindo autorização do ClickUp..."
        do {
            let baseURL = FirebaseAuthService.defaultBaseURL
            var req = URLRequest(url: URL(string: "\(baseURL)/api/integrations?action=clickup-auth")!)
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            struct AuthResponse: Decodable { let url: String }
            let authResp = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard let oauthURL = URL(string: authResp.url) else {
                clickUpStatusMessage = "URL de autorização inválida."
                isConnectingClickUp = false
                return
            }
            NSWorkspace.shared.open(oauthURL)
            // isConnectingClickUp stays true until handleClickUpOAuthCallback clears it
        } catch {
            clickUpStatusMessage = "Erro ao iniciar conexão com ClickUp: \(error.localizedDescription)"
            isConnectingClickUp = false
        }
    }

    func handleClickUpOAuthCallback(_ url: URL) {
        defer { isConnectingClickUp = false }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).compactMap {
            guard let v = $0.value else { return nil as (String, String)? }
            return ($0.name, v)
        })
        if let errMsg = params["error"] {
            clickUpStatusMessage = humanReadableOAuthError(errMsg, integration: "ClickUp")
            return
        }
        guard let accessToken = params["access_token"], !accessToken.isEmpty else {
            clickUpStatusMessage = "Resposta inválida do ClickUp."
            return
        }
        do {
            try keychainService.setString(accessToken, for: Self.clickUpTokenKey)
            clickUpStatusMessage = "ClickUp conectado com sucesso."
        } catch {
            clickUpStatusMessage = "Erro ao salvar token ClickUp: \(error.localizedDescription)"
        }
    }

    func runClickUpSync(for day: Date, force: Bool) async {
        guard canUse(.agendaIntegrations) else {
            if force {
                clickUpStatusMessage = lockMessage(for: .agendaIntegrations)
            }
            return
        }

        let settings = clickUpSettings.normalized()

        guard settings.isEnabled else {
            if force {
                clickUpStatusMessage = "Ative a integração do ClickUp para sincronizar esta fonte."
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
}
