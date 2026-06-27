import Foundation

extension ActivityStore {
    // MARK: - Zapier

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
            : "Integração com Zapier pausada."
    }

    func updateZapierWebhookURL(_ value: String) {
        guard !value.isEmpty else {
            monitoringPreferences.zapierSettings.webhooks = []
            persistMonitoringPreferences()
            return
        }
        let existing = monitoringPreferences.zapierSettings.webhooks
        if existing.contains(where: { $0.url == value }) { return }
        let wh = ZapierWebhook(url: value, label: "Webhook", events: [])
        monitoringPreferences.zapierSettings.webhooks = existing + [wh]
        persistMonitoringPreferences()
    }

    func saveZapierWebhookURLToServer(_ url: String) {
        let existing = monitoringPreferences.zapierSettings.webhooks
        let wh = ZapierWebhook(url: url, label: "Webhook", events: [])
        let updated = existing.contains(where: { $0.url == url }) ? existing : existing + [wh]
        Task { await runSaveZapierWebhooks(updated) }
    }

    func saveZapierWebhooksToServer(_ webhooks: [ZapierWebhook]) {
        Task { await runSaveZapierWebhooks(webhooks) }
    }

    func removeZapierWebhook() {
        Task { await runSaveZapierWebhooks([]) }
    }

    func removeZapierWebhook(id: UUID) {
        let updated = monitoringPreferences.zapierSettings.webhooks.filter { $0.id != id }
        monitoringPreferences.zapierSettings.webhooks = updated
        persistMonitoringPreferences()
        Task { await runSaveZapierWebhooks(updated) }
    }

    private func runSaveZapierWebhooks(_ webhooks: [ZapierWebhook]) async {
        guard let idToken = authSession?.idToken, !idToken.isEmpty else {
            zapierStatusMessage = "Faça login antes de configurar o Zapier."
            return
        }
        isSavingZapierWebhook = true
        defer { isSavingZapierWebhook = false }
        let baseURL = FirebaseAuthService.defaultBaseURL
        guard let endpoint = URL(string: "\(baseURL)/api/integrations?action=zapier-webhook-config") else {
            zapierStatusMessage = "Erro interno: URL de endpoint inválida."
            return
        }
        struct WebhookBody: Encodable {
            let url: String
            let label: String
            let events: [String]
        }
        struct Body: Encodable { let webhooks: [WebhookBody] }
        let body = Body(webhooks: webhooks.map {
            WebhookBody(url: $0.url, label: $0.label, events: Array($0.events))
        })
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverError = body["error"] as? String {
                    zapierStatusMessage = humanReadableOAuthError(serverError, integration: "Zapier")
                } else {
                    zapierStatusMessage = humanReadableOAuthError("server_not_configured", integration: "Zapier")
                }
                return
            }
            monitoringPreferences.zapierSettings.webhooks = webhooks
            persistMonitoringPreferences()
            zapierStatusMessage = webhooks.isEmpty ? "Zapier desconectado." : "Webhooks do Zapier salvos com sucesso."
        } catch {
            zapierStatusMessage = humanReadableOAuthError("network_error", integration: "Zapier")
        }
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

    func sendZapierFocusEventIfNeeded(type: String, profileTitle: String, details: [String: String]) async {
        guard zapierSettings.isEnabled,
              zapierSettings.sendsFocusEvents,
              zapierConfigured
        else { return }

        var payloadDetails = details
        payloadDetails["profile"] = profileTitle
        await sendZapierEvent(type: type, details: payloadDetails)
    }

    func sendZapierCalendarSyncEventIfNeeded(source: String, itemCount: Int) async {
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

    func sendZapierWorkspaceEventIfNeeded(memberCount: Int) async {
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

        let webhooks = zapierSettings.webhooks.filter { w in
            w.events.isEmpty || w.events.contains(type)
        }
        guard !webhooks.isEmpty else { return }

        let payload = ZapierWebhookPayload(
            eventType: type,
            sentAt: Date(),
            appName: "luum",
            organizationName: teamSettings.organizationName,
            memberName: teamSettings.memberDisplayName,
            details: details
        )

        var succeeded = 0
        var lastError: String?
        for wh in webhooks {
            do {
                try await zapierService.send(webhookURL: wh.url, payload: payload)
                succeeded += 1
            } catch {
                lastError = error.localizedDescription
            }
        }

        if succeeded > 0 {
            monitoringPreferences.zapierSettings.lastDeliveryAt = Date()
            persistMonitoringPreferences()
        }
        zapierStatusMessage = succeeded == webhooks.count
            ? "Webhook do Zapier entregue com sucesso."
            : lastError ?? "Erro ao entregar webhook do Zapier."
    }
}
