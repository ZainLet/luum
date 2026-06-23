import SwiftUI

struct SettingsView: View {
    @Bindable var store: ActivityStore
    @State private var isShowingSignOutConfirmation = false
    @State private var workspaceSecretDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Preferências",
                    title: "Conexões do Luum",
                    subtitle: "Conecte calendário, tarefas, automações, backup e IA sem lidar com chaves técnicas no app."
                )

                appVersionCard
                localVaultCard
                integrationHubCard
                aiClassificationCard
                googleCalendarCard
                pendingConnectionsCard
                teamCard
                privacyCard
                cloudSyncCard

                settingsCard(
                    title: "Permissoes de navegador",
                    lines: [
                        "Permite classificar sites pela aba ativa dos navegadores suportados.",
                        store.automationStatusMessage ?? "Tudo certo com a Automação do macOS.",
                    ],
                    tint: ActivityCategory.communication.glassTint
                )

                settingsCard(
                    title: "Monitoramento de entrada",
                    lines: [
                        store.inputMonitoringMessage ?? "Permissao ativa para detectar inatividade.",
                        "Opcional: o Luum continua funcionando sem ela.",
                    ],
                    tint: ActivityCategory.utilities.glassTint
                )

                settingsCard(
                    title: "Estado da captura",
                    lines: [
                        store.isMonitoring ? "Captura ativa em background." : "Captura pausada.",
                        "\(store.trackedAppsCount) apps e \(store.trackedSitesCount) sites no histórico.",
                    ],
                    tint: ActivityCategory.work.glassTint
                )

                actionRow
                classificationCard
            }
            .padding(28)
        }
        .background(LuumTheme.pageGradient.opacity(0.46))
        .task {
            store.refreshPublicIntegrationConfig()
        }
    }

    private var appVersionCard: some View {
        settingsCard(
            title: "Versão do app",
            lines: [
                "Luum \(AppVersionInfo.current.displayVersion)",
                "Build \(AppVersionInfo.current.build) • \(AppVersionInfo.current.channel)",
            ],
            tint: LuumTheme.accent.opacity(0.12)
        )
    }

    private var integrationHubCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mapa de integrações")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Veja rapidamente quais conexões estão prontas neste Mac.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(activeIntegrationCount)",
                    detail: "ativas"
                )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 176), spacing: 12)], spacing: 12) {
                ForEach(IntegrationKind.allCases) { kind in
                    IntegrationStatusTile(snapshot: integrationSnapshot(for: kind))
                }
            }

            if let message = store.publicIntegrationStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12), cornerRadius: 30)
    }

    private var localVaultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conta e cofre local")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Conta: \(store.accountEmail.isEmpty ? "Entre com sua conta Luum" : store.accountEmail)")
                .foregroundStyle(LuumTheme.textSecondary)
            Text("Armazenamento: \(store.secretStorageDescription)")
                .foregroundStyle(LuumTheme.textSecondary)
            Text(store.authStatusMessage ?? "Sessão local ainda não validada.")
                .foregroundStyle(LuumTheme.textSecondary)

            if store.isSignedIn {
                Button("Sair desta conta", role: .destructive) {
                    isShowingSignOutConfirmation = true
                }
                .buttonStyle(.bordered)
                .padding(.top, 6)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.16), cornerRadius: 30)
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
            Text("A sessão local será removida. Seus dados da conta no Firebase não serão apagados.")
        }
    }

    private var googleCalendarCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Google Agenda")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Conecte sua conta Google e compare sua agenda com o tempo real.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(store.googleCalendarConnections.count)",
                    detail: "contas"
                )
            }

            if let message = store.googleCalendarStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button("Conectar") {
                    store.connectGoogleCalendar()
                }
                .buttonStyle(.glassProminent)
                .disabled(store.isConnectingGoogleCalendar)

                Button("Sincronizar") {
                    store.refreshGoogleCalendar()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.isGoogleCalendarConnected || store.isSyncingGoogleCalendar)

                Button("Desconectar") {
                    store.disconnectAllGoogleCalendars()
                }
                .buttonStyle(.bordered)
                .disabled(!store.isGoogleCalendarConnected)
            }

            if store.googleCalendarConnections.isEmpty {
                Text("Nenhuma conta conectada ainda.")
                    .foregroundStyle(LuumTheme.textSecondary)
                    .padding(.top, 6)
            } else {
                VStack(spacing: 12) {
                    ForEach(store.googleCalendarConnections) { connection in
                        GoogleConnectionCard(store: store, connection: connection)
                    }
                }
            }

        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.14), cornerRadius: 30)
    }

    private var pendingConnectionsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Conexões em breve")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Essas integrações vão usar login guiado. Nada de token, chave ou webhook manual.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(pendingProviderConnectedCount)",
                    detail: "prontas"
                )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                pendingIntegrationRow(
                    title: pendingTitle(name: "Notion", isConnected: store.hasNotionToken, isAvailable: store.notionManagedOAuthAvailable),
                    subtitle: pendingSubtitle(connected: "Pronto para sincronizar quando ativado.", isConnected: store.hasNotionToken, isAvailable: store.notionManagedOAuthAvailable),
                    systemImage: "doc.text.image",
                    isConnected: store.hasNotionToken,
                    isAvailable: store.notionManagedOAuthAvailable
                )

                pendingIntegrationRow(
                    title: pendingTitle(name: "Outlook", isConnected: store.hasOutlookToken, isAvailable: store.outlookManagedOAuthAvailable),
                    subtitle: pendingSubtitle(connected: "Pronto para sincronizar quando ativado.", isConnected: store.hasOutlookToken, isAvailable: store.outlookManagedOAuthAvailable),
                    systemImage: "calendar",
                    isConnected: store.hasOutlookToken,
                    isAvailable: store.outlookManagedOAuthAvailable
                )

                pendingIntegrationRow(
                    title: pendingTitle(name: "ClickUp", isConnected: store.hasClickUpToken, isAvailable: store.clickUpManagedOAuthAvailable),
                    subtitle: pendingSubtitle(connected: "Pronto para sincronizar quando ativado.", isConnected: store.hasClickUpToken, isAvailable: store.clickUpManagedOAuthAvailable),
                    systemImage: "checklist",
                    isConnected: store.hasClickUpToken,
                    isAvailable: store.clickUpManagedOAuthAvailable
                )

                pendingIntegrationRow(
                    title: pendingTitle(name: "Linear", isConnected: store.hasLinearToken, isAvailable: store.linearManagedOAuthAvailable),
                    subtitle: pendingSubtitle(connected: "Pronto para sincronizar quando ativado.", isConnected: store.hasLinearToken, isAvailable: store.linearManagedOAuthAvailable),
                    systemImage: "arrow.up.right.square",
                    isConnected: store.hasLinearToken,
                    isAvailable: store.linearManagedOAuthAvailable
                )

                pendingIntegrationRow(
                    title: pendingTitle(name: "Zapier", isConnected: store.zapierConfigured, isAvailable: store.zapierManagedConnectionAvailable),
                    subtitle: pendingSubtitle(connected: "Automacao pronta neste Mac.", isConnected: store.zapierConfigured, isAvailable: store.zapierManagedConnectionAvailable),
                    systemImage: "bolt.horizontal",
                    isConnected: store.zapierConfigured,
                    isAvailable: store.zapierManagedConnectionAvailable
                )
            }

            pendingStatusMessages
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12), cornerRadius: 30)
    }

    @ViewBuilder
    private var pendingStatusMessages: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(pendingConnectionMessages, id: \.self) { message in
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var aiClassificationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("IA de classificação")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Sugira categorias para apps e sites usando a IA do Luum.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: store.aiClassificationConfigured ? "Pronta" : "Pendente",
                    detail: store.aiClassificationSettings.model
                )
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
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("A IA usa a configuração segura da sua conta Luum.")
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12), cornerRadius: 30)
    }

    private var teamCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Equipe e ranking")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Ranking de equipe conectado pela sua conta Luum.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: store.teamRankingUsesPreviewData ? "Preview" : "Live",
                    detail: "ranking"
                )
            }

            simpleInfoRow(
                systemImage: "person.2",
                title: store.teamSettings.organizationName.isEmpty ? "Workspace Luum" : store.teamSettings.organizationName,
                subtitle: store.teamSettings.memberDisplayName.isEmpty ? "Perfil da conta atual" : store.teamSettings.memberDisplayName
            )

            TextField("Workspace ID", text: Binding(
                get: { store.teamSettings.workspaceID },
                set: { store.updateTeamWorkspaceID($0) }
            ))
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                SecureField(
                    store.hasWorkspaceSecret ? "Chave salva neste Mac" : "Chave compartilhada do workspace",
                    text: $workspaceSecretDraft
                )
                .textFieldStyle(.roundedBorder)

                Button(store.hasWorkspaceSecret ? "Atualizar chave" : "Salvar chave") {
                    store.updateTeamWorkspaceSecret(workspaceSecretDraft)
                    workspaceSecretDraft = ""
                }
                .buttonStyle(.bordered)
                .disabled(workspaceSecretDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("O primeiro membro cria o workspace. Os demais usam o mesmo ID e a mesma chave de convite.")
                .font(.caption)
                .foregroundStyle(LuumTheme.textSecondary)

            Toggle("Compartilhar metricas anonimizadas no workspace", isOn: Binding(
                get: { store.teamSettings.sharesAnonymousMetrics },
                set: { store.updateTeamSharesAnonymousMetrics($0) }
            ))
            .toggleStyle(.switch)

            Toggle("Sincronizar ranking automaticamente", isOn: Binding(
                get: { store.teamSettings.automaticallySyncWorkspace },
                set: { store.updateTeamAutomaticallySyncWorkspace($0) }
            ))
            .toggleStyle(.switch)

            HStack(spacing: 10) {
                Button("Sincronizar") {
                    store.syncWorkspaceRankingNow()
                }
                .buttonStyle(.glassProminent)
                .disabled(!store.teamSettings.sharesAnonymousMetrics || !store.teamWorkspaceConfigured || store.isSyncingWorkspace)
            }

            if let message = store.workspaceSyncStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12), cornerRadius: 30)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Privacidade local")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Toggle("Salvar titulos das abas", isOn: Binding(
                get: { store.privacySettings.storesPageTitles },
                set: { store.updatePrivacyStorePageTitles($0) }
            ))
            .toggleStyle(.switch)

            Toggle("Salvar URLs completas", isOn: Binding(
                get: { store.privacySettings.storesFullURLs },
                set: { store.updatePrivacyStoreFullURLs($0) }
            ))
            .toggleStyle(.switch)

            Toggle("No backup, enviar apenas dominios", isOn: Binding(
                get: { store.privacySettings.syncOnlyDomains },
                set: { store.updatePrivacySyncOnlyDomains($0) }
            ))
            .toggleStyle(.switch)

            Stepper(value: Binding(
                get: { store.privacySettings.retentionDays },
                set: { store.updatePrivacyRetentionDays($0) }
            ), in: 7 ... 365, step: 1) {
                Text("Retenção local: \(store.privacySettings.retentionDays) dias")
                    .foregroundStyle(.white)
            }

            Text("Os titulos e URLs agora podem ser reduzidos automaticamente antes de irem para disco ou para o backup, o que melhora privacidade e desempenho.")
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 30)
    }

    private var cloudSyncCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Firebase / Firestore Sync")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Backup seguro da sua conta Luum para recuperar preferências e resumos.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if let cloudSyncLastSyncAt = store.cloudSyncLastSyncAt {
                    Text("Ultimo sync \(LuumFormatters.relativeTime(until: cloudSyncLastSyncAt))")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textMuted)
                }
            }

            Toggle("Ativar backup automatico", isOn: Binding(
                get: { store.cloudSyncSettings.isEnabled },
                set: { store.updateCloudSyncEnabled($0) }
            ))
            .toggleStyle(.switch)
            .disabled(!store.canUse(.cloudBackup))

            simpleInfoRow(
                systemImage: "person.crop.circle",
                title: store.accountEmail.isEmpty ? "Entre com sua conta Luum" : store.accountEmail,
                subtitle: store.cloudSyncConfigured ? "Backup pronto" : "Aguardando login e plano compatível"
            )

            HStack(spacing: 10) {
                Button("Sincronizar agora") {
                    store.syncCloudBackupNow()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canUse(.cloudBackup) || !store.cloudSyncConfigured || store.isSyncingCloud)

                Button("Restaurar backup") {
                    store.restoreCloudBackup()
                }
                .buttonStyle(.bordered)
                .disabled(!store.canUse(.cloudBackup) || !store.cloudSyncConfigured || store.isSyncingCloud)
            }

            Toggle("Sincronizar atividades brutas", isOn: Binding(
                get: { store.cloudSyncSettings.syncRawActivities },
                set: { store.updateCloudSyncSyncRawActivities($0) }
            ))
            .toggleStyle(.switch)
            .disabled(!store.canUse(.rawActivityBackup))

            if let cloudSyncStatusMessage = store.cloudSyncStatusMessage {
                Text(cloudSyncStatusMessage)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Dados sensíveis das conexões ficam fora do backup.")
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .luumGlassCard(tint: ActivityCategory.work.glassTint, cornerRadius: 30)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button("Abrir Privacidade > Automacao") {
                SystemSettings.openAutomationPrivacy()
            }
            .buttonStyle(.glassProminent)

            Button("Solicitar monitoramento de entrada") {
                store.requestInputMonitoringAccess()
            }
            .buttonStyle(.borderedProminent)

            Button("Abrir pasta do histórico") {
                SystemSettings.openActivityLogFolder()
            }
            .buttonStyle(.bordered)
        }
    }

    private var classificationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Classificação inicial")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ForEach(store.rulePreviews) { preview in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: preview.category.systemImage)
                        .foregroundStyle(preview.category.tint)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preview.category.title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(preview.examples.joined(separator: ", "))
                            .foregroundStyle(LuumTheme.textSecondary)
                    }
                }
                .padding(16)
                .luumGlassCard(tint: preview.category.glassTint, cornerRadius: 26, shadowOpacity: 0.14)
            }
        }
    }

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
        .filter { $0 }
        .count
    }

    private var pendingProviderConnectedCount: Int {
        [
            store.hasNotionToken,
            store.hasOutlookToken,
            store.hasClickUpToken,
            store.hasLinearToken,
            store.zapierConfigured,
        ]
        .filter { $0 }
        .count
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
        .compactMap { message in
            let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return nil }
            seen.insert(trimmed)
            return trimmed
        }
    }

    private func integrationSnapshot(for kind: IntegrationKind) -> IntegrationSnapshot {
        switch kind {
        case .aiClassification:
            if store.aiClassificationConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: AIClassificationService.isLuumBackendEndpoint(store.aiClassificationSettings.endpointURL)
                        ? "Protegida pela conta Luum"
                        : "\(store.aiClassificationSettings.providerName) \(store.aiClassificationSettings.model)",
                    tint: LuumTheme.secondaryAccent
                )
            }

            if store.aiClassificationSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: AIClassificationService.isLuumBackendEndpoint(store.aiClassificationSettings.endpointURL)
                        ? "Entre no Luum para liberar"
                        : "Configuração pendente",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Sugestões opcionais",
                tint: LuumTheme.textMuted
            )
        case .googleCalendar:
            if store.isGoogleCalendarConnected {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: "\(store.googleCalendarConnections.count) conta(s) conectada(s)",
                    tint: LuumTheme.electricBlue
                )
            }

            if store.isGoogleCalendarConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Pronto",
                    detail: "Login disponivel",
                    tint: LuumTheme.secondaryAccent
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Pendente",
                detail: "Conexão pendente",
                tint: LuumTheme.textMuted
            )
        case .notionCalendar:
            if store.notionCalendarSettings.isEnabled && store.notionCalendarConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: "\(store.notionCalendarSettings.databaseIDs.count) fonte(s) conectada(s)",
                    tint: LuumTheme.secondaryAccent
                )
            }

            if store.notionManagedOAuthAvailable {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Pronto",
                    detail: "Conexão guiada preparada",
                    tint: LuumTheme.secondaryAccent
                )
            }

            if store.notionCalendarSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Conexão pendente",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integração opcional",
                tint: LuumTheme.textMuted
            )
        case .outlookCalendar:
            if store.outlookCalendarSettings.isEnabled && store.outlookCalendarConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: "\(store.outlookCalendarSettings.calendars.filter(\.isSelected).count) calendário(s) sincronizados",
                    tint: LuumTheme.electricBlue
                )
            }

            if store.outlookManagedOAuthAvailable {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Pronto",
                    detail: "Conexão guiada preparada",
                    tint: LuumTheme.electricBlue
                )
            }

            if store.outlookCalendarSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Conexão pendente",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integração opcional",
                tint: LuumTheme.textMuted
            )
        case .clickUp:
            if store.clickUpSettings.isEnabled && store.clickUpConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: "\(store.clickUpSettings.listIDs.count) lista(s) conectada(s)",
                    tint: LuumTheme.hotPink
                )
            }

            if store.clickUpManagedOAuthAvailable {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Pronto",
                    detail: "Conexão guiada preparada",
                    tint: LuumTheme.secondaryAccent
                )
            }

            if store.clickUpSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Conexão pendente",
                    tint: LuumTheme.secondaryAccent
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integração opcional",
                tint: LuumTheme.textMuted
            )
        case .linear:
            if store.linearSettings.isEnabled && store.linearConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: "\(store.linearSettings.teamIDs.count) time(s) conectados",
                    tint: LuumTheme.secondaryAccent
                )
            }

            if store.linearManagedOAuthAvailable {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Pronto",
                    detail: "Conexão guiada preparada",
                    tint: LuumTheme.secondaryAccent
                )
            }

            if store.linearSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Conexão pendente",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integração opcional",
                tint: LuumTheme.textMuted
            )
        case .zapier:
            if store.zapierSettings.isEnabled && store.zapierConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: "Automações prontas",
                    tint: ActivityCategory.work.tint
                )
            }

            if store.zapierManagedConnectionAvailable {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Pronto",
                    detail: "Conexão guiada preparada",
                    tint: ActivityCategory.work.tint
                )
            }

            if store.zapierSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Conexão pendente",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integração opcional",
                tint: LuumTheme.textMuted
            )
        case .firebaseSync:
            if store.cloudSyncSettings.isEnabled && store.cloudSyncConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: "Backup pronto para nuvem",
                    tint: ActivityCategory.work.tint
                )
            }

            if store.cloudSyncSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Entre no Luum para ativar",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Sync opcional",
                tint: LuumTheme.textMuted
            )
        }
    }

    private func pendingTitle(name: String, isConnected: Bool, isAvailable: Bool) -> String {
        if isConnected {
            return "\(name) conectado"
        }
        return isAvailable ? "Conectar \(name)" : "\(name) em breve"
    }

    private func pendingSubtitle(connected: String, isConnected: Bool, isAvailable: Bool) -> String {
        if isConnected {
            return connected
        }
        return isAvailable
            ? "Conexão guiada disponível pela conta Luum."
            : "Login guiado será liberado pelo Luum, sem token manual."
    }

    private func settingsCard(title: String, lines: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .luumGlassCard(tint: tint, cornerRadius: 30)
    }

    private func simpleInfoRow(systemImage: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.045))
        )
    }

    private func pendingIntegrationRow(title: String, subtitle: String, systemImage: String, isConnected: Bool, isAvailable: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isConnected {
                Button("Conectado") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
            } else if isAvailable {
                Button("Conectar") {}
                    .buttonStyle(.glassProminent)
                    .disabled(true)
            } else {
                Button("Em breve") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.045))
        )
    }
}

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

private struct ChipListCard: View {
    let title: String
    let items: [String]
    let tint: Color
    let onDelete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            VStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(tint)
                            .frame(width: 8, height: 8)

                        Text(item)
                            .foregroundStyle(.white)
                            .font(.caption.weight(.semibold))
                            .textSelection(.enabled)

                        Spacer()

                        Button(role: .destructive) {
                            onDelete(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white.opacity(0.03))
                    )
                }
            }
        }
    }
}

private struct IntegrationSnapshot: Identifiable {
    let kind: IntegrationKind
    let status: String
    let detail: String
    let tint: Color

    var id: String { kind.id }
}

private struct IntegrationStatusTile: View {
    let snapshot: IntegrationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: snapshot.kind.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(snapshot.tint)

            Text(snapshot.kind.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Text(snapshot.status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(snapshot.tint)

            Text(snapshot.detail)
                .font(.caption)
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(snapshot.tint.opacity(0.14))
        }
    }
}

private struct GoogleConnectionCard: View {
    @Bindable var store: ActivityStore
    let connection: GoogleCalendarConnectionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { connection.isEnabled },
                    set: { store.setGoogleCalendarConnectionEnabled(connection.id, isEnabled: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
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

            VStack(alignment: .leading, spacing: 10) {
                Text("Calendários incluídos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(connection.calendars) { calendar in
                        Toggle(isOn: Binding(
                            get: { calendar.isSelected },
                            set: { store.setCalendarSelection(connectionID: connection.id, calendarID: calendar.id, isSelected: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
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
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.white.opacity(0.02))
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.02))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.05))
        }
    }
}
