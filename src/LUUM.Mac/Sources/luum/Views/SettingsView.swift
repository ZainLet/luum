import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @Bindable var store: ActivityStore
    @State private var isShowingSignOutConfirmation = false
    @State private var workspaceSecretDraft = ""
    @State private var tab: SettingsTab = .conta

    private enum SettingsTab: String, CaseIterable {
        case conta = "Conta"
        case integracoes = "Integrações"
        case captura = "Captura"
        case backup = "Backup"

        var symbol: String {
            switch self {
            case .conta:       "person.crop.circle"
            case .integracoes: "network"
            case .captura:     "record.circle"
            case .backup:      "icloud"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.08)
            tabContent
        }
        .task { store.refreshPublicIntegrationConfig() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            LuumSectionHeader(
                eyebrow: "Preferências",
                title: "Configurações",
                subtitle: "Conta, integrações, captura e backup — tudo em um lugar."
            )

            Picker("", selection: $tab) {
                ForEach(SettingsTab.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.symbol).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                switch tab {
                case .conta:       contaSection
                case .integracoes: integracoesSection
                case .captura:     capturaSection
                case .backup:      backupSection
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .animation(.easeInOut(duration: 0.2), value: tab)
    }

    // MARK: - Conta

    @ViewBuilder
    private var contaSection: some View {
        // App version + channel
        SettingsRow(
            symbol: "info.circle",
            title: "Versão do app",
            tint: LuumTheme.accent
        ) {
            Text("Luum \(AppVersionInfo.current.displayVersion)")
                .foregroundStyle(.white)
            Text("Build \(AppVersionInfo.current.build) · \(AppVersionInfo.current.channel)")
                .foregroundStyle(LuumTheme.textSecondary)
        }

        // Account
        SettingsRow(
            symbol: "person.crop.circle",
            title: "Conta",
            tint: LuumTheme.secondaryAccent
        ) {
            if store.accountEmail.isEmpty {
                Text("Não conectado").foregroundStyle(LuumTheme.textSecondary)
            } else {
                Text(store.accountEmail).foregroundStyle(.white)
                Text("Plano \(store.accountPlan.title)")
                    .foregroundStyle(LuumTheme.textSecondary)
            }
            if let status = store.authStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textMuted)
            }

            if store.isSignedIn {
                Button("Sair desta conta", role: .destructive) {
                    isShowingSignOutConfirmation = true
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .confirmationDialog(
            "Sair desta conta neste Mac?",
            isPresented: $isShowingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sair desta conta", role: .destructive) {
                workspaceSecretDraft = ""
                store.signOut()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A sessão local será removida. Seus dados no Firebase não serão apagados.")
        }

        // Storage
        SettingsRow(
            symbol: "lock.shield",
            title: "Cofre local",
            tint: LuumTheme.electricBlue
        ) {
            Text(store.secretStorageDescription)
                .foregroundStyle(LuumTheme.textSecondary)
            Text("\(store.trackedAppsCount) apps · \(store.trackedSitesCount) sites no histórico")
                .foregroundStyle(LuumTheme.textMuted)
                .font(.caption)
        }
    }

    // MARK: - Integrações

    @ViewBuilder
    private var integracoesSection: some View {
        // Status grid
        integrationStatusGrid

        Divider().opacity(0.08)

        // Google Calendar
        googleCalendarSection

        Divider().opacity(0.08)

        // Pending (coming soon)
        pendingIntegrationsSection

        Divider().opacity(0.08)

        // AI
        aiClassificationSection
    }

    private var integrationStatusGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Status das integrações")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(activeIntegrationCount) ativas")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LuumTheme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.06)))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                ForEach(IntegrationKind.allCases) { kind in
                    IntegrationStatusTile(snapshot: integrationSnapshot(for: kind))
                }
            }

            if let message = store.publicIntegrationStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }
        }
    }

    private var googleCalendarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Google Agenda", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(store.googleCalendarConnections.count) conta(s)")
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textMuted)
            }

            if let message = store.googleCalendarStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }

            HStack(spacing: 10) {
                Button("Conectar") { store.connectGoogleCalendar() }
                    .buttonStyle(.glassProminent)
                    .disabled(store.isConnectingGoogleCalendar)

                Button("Sincronizar") { store.refreshGoogleCalendar() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.isGoogleCalendarConnected || store.isSyncingGoogleCalendar)

                Button("Desconectar") { store.disconnectAllGoogleCalendars() }
                    .buttonStyle(.bordered)
                    .disabled(!store.isGoogleCalendarConnected)
            }

            if store.googleCalendarConnections.isEmpty {
                Text("Nenhuma conta conectada ainda.")
                    .foregroundStyle(LuumTheme.textSecondary)
                    .font(.subheadline)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.googleCalendarConnections) { connection in
                        GoogleConnectionCard(store: store, connection: connection)
                    }
                }
            }
        }
    }

    private var pendingIntegrationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Em breve")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("Sem token manual")
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textMuted)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                pendingIntegrationRow(
                    name: "Notion",
                    systemImage: "doc.text.image",
                    isConnected: store.hasNotionToken,
                    isAvailable: store.notionManagedOAuthAvailable
                )
                pendingIntegrationRow(
                    name: "Outlook",
                    systemImage: "calendar",
                    isConnected: store.hasOutlookToken,
                    isAvailable: store.outlookManagedOAuthAvailable
                )
                pendingIntegrationRow(
                    name: "ClickUp",
                    systemImage: "checklist",
                    isConnected: store.hasClickUpToken,
                    isAvailable: store.clickUpManagedOAuthAvailable
                )
                pendingIntegrationRow(
                    name: "Linear",
                    systemImage: "arrow.up.right.square",
                    isConnected: store.hasLinearToken,
                    isAvailable: store.linearManagedOAuthAvailable
                )
                pendingIntegrationRow(
                    name: "Zapier",
                    systemImage: "bolt.horizontal",
                    isConnected: store.zapierConfigured,
                    isAvailable: store.zapierManagedConnectionAvailable
                )
            }

            let messages = pendingConnectionMessages
            if !messages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(messages, id: \.self) { msg in
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(LuumTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var aiClassificationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("IA de classificação", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(store.aiClassificationConfigured ? "Pronta" : "Pendente")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.aiClassificationConfigured ? LuumTheme.emerald : LuumTheme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.06)))
            }

            Toggle("Ativar sugestões por IA", isOn: Binding(
                get: { store.aiClassificationSettings.isEnabled },
                set: { store.updateAIClassificationEnabled($0) }
            ))
            .toggleStyle(.switch)

            if let message = store.aiClassificationStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }

            Text("A IA usa a configuração segura da sua conta Luum — sem expor chaves.")
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)
        }
    }

    // MARK: - Captura

    @ViewBuilder
    private var capturaSection: some View {
        // Estado atual
        SettingsRow(
            symbol: store.isMonitoring ? "circle.fill" : "circle.slash",
            title: "Estado da captura",
            tint: store.isMonitoring ? LuumTheme.emerald : LuumTheme.textMuted
        ) {
            Text(store.isMonitoring ? "Captura ativa em background." : "Captura pausada.")
                .foregroundStyle(.white)
            Text("\(store.trackedAppsCount) apps · \(store.trackedSitesCount) sites no histórico")
                .foregroundStyle(LuumTheme.textSecondary)
                .font(.caption)
        }

        // Permissões do sistema
        SettingsRow(
            symbol: "safari",
            title: "Permissão de navegador",
            tint: ActivityCategory.communication.tint
        ) {
            Text(store.automationStatusMessage ?? "Automação do macOS autorizada.")
                .foregroundStyle(LuumTheme.textSecondary)
            Text("Necessária para classificar sites pela aba ativa.")
                .foregroundStyle(LuumTheme.textMuted)
                .font(.caption)

            Button("Abrir Privacidade › Automação") {
                SystemSettings.openAutomationPrivacy()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }

        SettingsRow(
            symbol: "keyboard",
            title: "Monitoramento de entrada",
            tint: ActivityCategory.utilities.tint
        ) {
            Text(store.inputMonitoringMessage ?? "Permissão ativa para detectar inatividade.")
                .foregroundStyle(LuumTheme.textSecondary)
            Text("Opcional — o Luum funciona sem ela.")
                .foregroundStyle(LuumTheme.textMuted)
                .font(.caption)

            Button("Solicitar acesso") {
                store.requestInputMonitoringAccess()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }

        // Histórico local
        SettingsRow(
            symbol: "folder",
            title: "Histórico local",
            tint: LuumTheme.electricBlue
        ) {
            Text("Atividades salvas em JSON no Application Support.")
                .foregroundStyle(LuumTheme.textSecondary)

            Button("Abrir pasta do histórico") {
                SystemSettings.openActivityLogFolder()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }

        // Privacidade
        VStack(alignment: .leading, spacing: 14) {
            Text("Privacidade local")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                Toggle("Salvar títulos das abas", isOn: Binding(
                    get: { store.privacySettings.storesPageTitles },
                    set: { store.updatePrivacyStorePageTitles($0) }
                )).toggleStyle(.switch)

                Toggle("Salvar URLs completas", isOn: Binding(
                    get: { store.privacySettings.storesFullURLs },
                    set: { store.updatePrivacyStoreFullURLs($0) }
                )).toggleStyle(.switch)

                Toggle("No backup, enviar apenas domínios", isOn: Binding(
                    get: { store.privacySettings.syncOnlyDomains },
                    set: { store.updatePrivacySyncOnlyDomains($0) }
                )).toggleStyle(.switch)
            }

            Stepper(value: Binding(
                get: { store.privacySettings.retentionDays },
                set: { store.updatePrivacyRetentionDays($0) }
            ), in: 7 ... 365) {
                Text("Retenção local: \(store.privacySettings.retentionDays) dias")
                    .foregroundStyle(.white)
            }

            Text("Títulos e URLs podem ser reduzidos antes de irem para disco ou backup.")
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)
        }
        .padding(20)
        .luumCard(cornerRadius: 20)
    }

    // MARK: - Backup

    @ViewBuilder
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Firebase / Firestore Sync", systemImage: "icloud")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if let lastSync = store.cloudSyncLastSyncAt {
                    Text("Sync \(LuumFormatters.relativeTime(until: lastSync))")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textMuted)
                }
            }

            Text("Backup seguro da sua conta Luum para recuperar preferências e resumos.")
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Ativar backup automático", isOn: Binding(
                get: { store.cloudSyncSettings.isEnabled },
                set: { store.updateCloudSyncEnabled($0) }
            ))
            .toggleStyle(.switch)
            .disabled(!store.canUse(.cloudBackup))

            Toggle("Incluir atividades brutas", isOn: Binding(
                get: { store.cloudSyncSettings.syncRawActivities },
                set: { store.updateCloudSyncSyncRawActivities($0) }
            ))
            .toggleStyle(.switch)
            .disabled(!store.canUse(.rawActivityBackup))

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 3) {
                    Text(store.accountEmail.isEmpty ? "Entre com sua conta Luum" : store.accountEmail)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(store.cloudSyncConfigured ? "Backup pronto" : "Aguardando login e plano compatível")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))

            HStack(spacing: 10) {
                Button("Sincronizar agora") { store.syncCloudBackupNow() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canUse(.cloudBackup) || !store.cloudSyncConfigured || store.isSyncingCloud)

                Button("Restaurar backup") { store.restoreCloudBackup() }
                    .buttonStyle(.bordered)
                    .disabled(!store.canUse(.cloudBackup) || !store.cloudSyncConfigured || store.isSyncingCloud)
            }

            if let message = store.cloudSyncStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }

            Text("Dados sensíveis das conexões ficam fora do backup.")
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)
        }
        .padding(20)
        .luumCard(cornerRadius: 20)
    }

    // MARK: - Helpers

    private var activeIntegrationCount: Int {
        [
            store.aiClassificationConfigured,
            store.isGoogleCalendarConnected,
            store.notionCalendarSettings.isEnabled && store.notionCalendarConfigured,
            store.outlookCalendarSettings.isEnabled && store.outlookCalendarConfigured,
            store.clickUpSettings.isEnabled && store.clickUpConfigured,
            store.linearSettings.isEnabled && store.linearConfigured,
            store.zapierSettings.isEnabled && store.zapierConfigured,
            store.cloudSyncSettings.isEnabled && store.cloudSyncConfigured,
        ]
        .filter { $0 }.count
    }

    private var pendingConnectionMessages: [String] {
        var seen: Set<String> = []
        return [
            store.notionCalendarStatusMessage,
            store.outlookCalendarStatusMessage,
            store.clickUpStatusMessage,
            store.linearStatusMessage,
            store.zapierStatusMessage,
        ]
        .compactMap { msg in
            let trimmed = msg?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return nil }
            seen.insert(trimmed)
            return trimmed
        }
    }

    private func integrationSnapshot(for kind: IntegrationKind) -> IntegrationSnapshot {
        switch kind {
        case .aiClassification:
            if store.aiClassificationConfigured {
                return .init(kind: kind, status: "Ativo",
                    detail: AIClassificationService.isLuumBackendEndpoint(store.aiClassificationSettings.endpointURL)
                        ? "Protegida pela conta Luum"
                        : "\(store.aiClassificationSettings.providerName) \(store.aiClassificationSettings.model)",
                    tint: LuumTheme.secondaryAccent)
            }
            if store.aiClassificationSettings.isEnabled {
                return .init(kind: kind, status: "Parcial",
                    detail: AIClassificationService.isLuumBackendEndpoint(store.aiClassificationSettings.endpointURL)
                        ? "Entre no Luum para liberar" : "Configuração pendente",
                    tint: LuumTheme.hotPink)
            }
            return .init(kind: kind, status: "Desativado", detail: "Sugestões opcionais", tint: LuumTheme.textMuted)

        case .googleCalendar:
            if store.isGoogleCalendarConnected {
                return .init(kind: kind, status: "Ativo",
                    detail: "\(store.googleCalendarConnections.count) conta(s) conectada(s)",
                    tint: LuumTheme.electricBlue)
            }
            if store.isGoogleCalendarConfigured {
                return .init(kind: kind, status: "Pronto", detail: "Login disponível", tint: LuumTheme.secondaryAccent)
            }
            return .init(kind: kind, status: "Pendente", detail: "Conexão pendente", tint: LuumTheme.textMuted)

        case .notionCalendar:
            if store.notionCalendarSettings.isEnabled && store.notionCalendarConfigured {
                return .init(kind: kind, status: "Ativo",
                    detail: "\(store.notionCalendarSettings.databaseIDs.count) fonte(s)",
                    tint: LuumTheme.secondaryAccent)
            }
            if store.notionManagedOAuthAvailable {
                return .init(kind: kind, status: "Pronto", detail: "Conexão guiada preparada", tint: LuumTheme.secondaryAccent)
            }
            if store.notionCalendarSettings.isEnabled {
                return .init(kind: kind, status: "Parcial", detail: "Conexão pendente", tint: LuumTheme.hotPink)
            }
            return .init(kind: kind, status: "Desativado", detail: "Integração opcional", tint: LuumTheme.textMuted)

        case .outlookCalendar:
            if store.outlookCalendarSettings.isEnabled && store.outlookCalendarConfigured {
                return .init(kind: kind, status: "Ativo",
                    detail: "\(store.outlookCalendarSettings.calendars.filter(\.isSelected).count) calendário(s)",
                    tint: LuumTheme.electricBlue)
            }
            if store.outlookManagedOAuthAvailable {
                return .init(kind: kind, status: "Pronto", detail: "Conexão guiada preparada", tint: LuumTheme.electricBlue)
            }
            if store.outlookCalendarSettings.isEnabled {
                return .init(kind: kind, status: "Parcial", detail: "Conexão pendente", tint: LuumTheme.hotPink)
            }
            return .init(kind: kind, status: "Desativado", detail: "Integração opcional", tint: LuumTheme.textMuted)

        case .clickUp:
            if store.clickUpSettings.isEnabled && store.clickUpConfigured {
                return .init(kind: kind, status: "Ativo",
                    detail: "\(store.clickUpSettings.listIDs.count) lista(s)",
                    tint: LuumTheme.hotPink)
            }
            if store.clickUpManagedOAuthAvailable {
                return .init(kind: kind, status: "Pronto", detail: "Conexão guiada preparada", tint: LuumTheme.secondaryAccent)
            }
            if store.clickUpSettings.isEnabled {
                return .init(kind: kind, status: "Parcial", detail: "Conexão pendente", tint: LuumTheme.secondaryAccent)
            }
            return .init(kind: kind, status: "Desativado", detail: "Integração opcional", tint: LuumTheme.textMuted)

        case .linear:
            if store.linearSettings.isEnabled && store.linearConfigured {
                return .init(kind: kind, status: "Ativo",
                    detail: "\(store.linearSettings.teamIDs.count) time(s)",
                    tint: LuumTheme.secondaryAccent)
            }
            if store.linearManagedOAuthAvailable {
                return .init(kind: kind, status: "Pronto", detail: "Conexão guiada preparada", tint: LuumTheme.secondaryAccent)
            }
            if store.linearSettings.isEnabled {
                return .init(kind: kind, status: "Parcial", detail: "Conexão pendente", tint: LuumTheme.hotPink)
            }
            return .init(kind: kind, status: "Desativado", detail: "Integração opcional", tint: LuumTheme.textMuted)

        case .zapier:
            if store.zapierSettings.isEnabled && store.zapierConfigured {
                return .init(kind: kind, status: "Ativo", detail: "Automações prontas", tint: ActivityCategory.work.tint)
            }
            if store.zapierManagedConnectionAvailable {
                return .init(kind: kind, status: "Pronto", detail: "Conexão guiada preparada", tint: ActivityCategory.work.tint)
            }
            if store.zapierSettings.isEnabled {
                return .init(kind: kind, status: "Parcial", detail: "Conexão pendente", tint: LuumTheme.hotPink)
            }
            return .init(kind: kind, status: "Desativado", detail: "Automação opcional", tint: LuumTheme.textMuted)

        case .firebaseSync:
            if store.cloudSyncSettings.isEnabled && store.cloudSyncConfigured {
                return .init(kind: kind, status: "Ativo", detail: "Backup pronto para nuvem", tint: ActivityCategory.work.tint)
            }
            if store.cloudSyncSettings.isEnabled {
                return .init(kind: kind, status: "Parcial", detail: "Entre no Luum para ativar", tint: LuumTheme.hotPink)
            }
            return .init(kind: kind, status: "Desativado", detail: "Sync opcional", tint: LuumTheme.textMuted)
        }
    }

    private func pendingIntegrationRow(name: String, systemImage: String, isConnected: Bool, isAvailable: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(isConnected ? "\(name) conectado" : (isAvailable ? "Conectar \(name)" : "\(name) em breve"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(isConnected
                    ? "Pronto para sincronizar."
                    : (isAvailable ? "Conexão guiada disponível." : "Login guiado será liberado pelo Luum."))
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(LuumTheme.emerald)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
    }
}

// MARK: - SettingsRow

private struct SettingsRow<Content: View>: View {
    let symbol: String
    let title: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            content
                .padding(.leading, 38)
        }
        .padding(20)
        .luumCard(cornerRadius: 20)
    }
}

// MARK: - AppVersionInfo

private struct AppVersionInfo {
    let version: String
    let build: String
    let channel: String

    static var current: AppVersionInfo {
        let bundle = Bundle.main
        return AppVersionInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "local",
            channel: bundle.object(forInfoDictionaryKey: "LuumReleaseChannel") as? String ?? "development"
        )
    }

    var displayVersion: String {
        channel == "development" ? version : "\(version)-\(channel)"
    }
}

// MARK: - IntegrationSnapshot

private struct IntegrationSnapshot: Identifiable {
    let kind: IntegrationKind
    let status: String
    let detail: String
    let tint: Color

    var id: String { kind.id }
}

// MARK: - IntegrationStatusTile

private struct IntegrationStatusTile: View {
    let snapshot: IntegrationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: snapshot.kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(snapshot.tint)

            Text(snapshot.kind.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(snapshot.status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(snapshot.tint)

            Text(snapshot.detail)
                .font(.caption)
                .foregroundStyle(LuumTheme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(snapshot.tint.opacity(0.12))
        }
    }
}

// MARK: - GoogleConnectionCard

private struct GoogleConnectionCard: View {
    @Bindable var store: ActivityStore
    let connection: GoogleCalendarConnectionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { connection.isEnabled },
                    set: { store.setGoogleCalendarConnectionEnabled(connection.id, isEnabled: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(connection.profile.name)
                            .foregroundStyle(.white)
                            .font(.headline)
                        Text(connection.profile.email)
                            .foregroundStyle(LuumTheme.textSecondary)
                            .font(.caption)
                    }
                }
                .toggleStyle(.switch)

                Spacer()

                Button(role: .destructive) {
                    store.disconnectGoogleCalendar(connectionID: connection.id)
                } label: {
                    Label("Remover", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }

            Text("Calendários incluídos")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], spacing: 8) {
                ForEach(connection.calendars) { calendar in
                    Toggle(isOn: Binding(
                        get: { calendar.isSelected },
                        set: { store.setCalendarSelection(connectionID: connection.id, calendarID: calendar.id, isSelected: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calendar.title)
                                .foregroundStyle(.white)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(calendar.isPrimary ? "Principal" : (calendar.accessRole ?? "calendar"))
                                .foregroundStyle(LuumTheme.textSecondary)
                                .font(.caption2)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.02)))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.02)))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.05)) }
    }
}
