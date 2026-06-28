import AppKit
import Foundation

extension ActivityStore {
    // MARK: - Linear

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
            linearStatusMessage = "Integração do Linear pausada."
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

    func connectLinear() { isConnectingLinear = true; Task { await runLinearConnect() } }

    func disconnectLinear() {
        keychainService.removeValue(for: Self.linearTokenKey)
        monitoringPreferences.linearSettings.isEnabled = false
        linearAgendaItems = []; linearAgendaDay = nil
        linearStatusMessage = "Linear desconectado."
        persistMonitoringPreferences()
    }

    func runLinearConnect() async {
        guard canUse(.agendaIntegrations) else {
            linearStatusMessage = lockMessage(for: .agendaIntegrations)
            isConnectingLinear = false
            return
        }
        guard let idToken = authSession?.idToken, !idToken.isEmpty else {
            linearStatusMessage = "Faça login antes de conectar o Linear."
            isConnectingLinear = false
            return
        }
        linearStatusMessage = "Abrindo autorização do Linear..."
        do {
            let baseURL = FirebaseAuthService.defaultBaseURL
            var req = URLRequest(url: URL(string: "\(baseURL)/api/integrations?action=linear-auth")!)
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            struct AuthResponse: Decodable { let url: String }
            let authResp = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard let oauthURL = URL(string: authResp.url) else {
                linearStatusMessage = "URL de autorização inválida."
                isConnectingLinear = false
                return
            }
            NSWorkspace.shared.open(oauthURL)
            // isConnectingLinear stays true until handleLinearOAuthCallback clears it
        } catch {
            linearStatusMessage = "Erro ao iniciar conexão com Linear: \(error.localizedDescription)"
            isConnectingLinear = false
        }
    }

    func handleLinearOAuthCallback(_ url: URL) {
        defer { isConnectingLinear = false }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).compactMap {
            guard let v = $0.value else { return nil as (String, String)? }
            return ($0.name, v)
        })
        if let errMsg = params["error"] {
            switch errMsg {
            case "invalid_state", "missing_state":
                linearStatusMessage = "Sessão expirada. Tente conectar novamente."
            case "server_not_configured":
                linearStatusMessage = "Linear não está configurado no servidor."
            case "access_denied":
                linearStatusMessage = "Autorização negada. Permita o acesso para conectar."
            default:
                linearStatusMessage = "Erro ao conectar Linear. Tente novamente."
            }
            return
        }
        guard let accessToken = params["access_token"], !accessToken.isEmpty else {
            linearStatusMessage = "Resposta inválida do Linear."
            return
        }
        do {
            let rawTokenType = params["token_type"]
            let tokenType = rawTokenType.flatMap {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
            } ?? "Bearer"
            try keychainService.setString("\(tokenType) \(accessToken)", for: Self.linearTokenKey)
            linearStatusMessage = "Linear conectado com sucesso."
        } catch {
            linearStatusMessage = "Erro ao salvar token Linear: \(error.localizedDescription)"
        }
    }

    func runLinearSync(for day: Date, force: Bool) async {
        guard canUse(.agendaIntegrations) else {
            if force {
                linearStatusMessage = lockMessage(for: .agendaIntegrations)
            }
            return
        }

        let settings = linearSettings.normalized()

        guard settings.isEnabled else {
            if force {
                linearStatusMessage = "Ative a integração do Linear para sincronizar esta fonte."
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
}
