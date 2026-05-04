import SwiftUI

struct SettingsView: View {
    @Bindable var store: ActivityStore

    @State private var backupSecretDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Preferencias",
                    title: "Centro de configuracao",
                    subtitle: "Aqui ficam a agenda multi-conta, a privacidade local, o backup em Firestore e os controles de automacao do luum."
                )

                googleCalendarCard
                privacyCard
                cloudSyncCard

                settingsCard(
                    title: "Permissoes de navegador",
                    lines: [
                        "Safari, Chrome, Arc, Brave, Edge, Opera, Chromium e Vivaldi podem fornecer a URL da aba ativa.",
                        "O macOS pede permissao de Automacao na primeira tentativa de leitura.",
                        store.automationStatusMessage ?? "Nenhum erro recente de Automacao.",
                    ],
                    tint: ActivityCategory.communication.glassTint
                )

                settingsCard(
                    title: "Monitoramento de entrada",
                    lines: [
                        store.inputMonitoringMessage ?? "Permissao de Monitoramento de Entrada ativa. O luum consegue detectar inatividade.",
                        "Essa permissao e opcional: sem ela, o app continua monitorando apps e URLs normalmente.",
                    ],
                    tint: ActivityCategory.utilities.glassTint
                )

                settingsCard(
                    title: "Estado da captura",
                    lines: [
                        store.isMonitoring ? "Captura ativa em background." : "Captura pausada.",
                        "Apps acompanhados no historico: \(store.trackedAppsCount)",
                        "Sites enriquecidos no historico: \(store.trackedSitesCount)",
                    ],
                    tint: ActivityCategory.work.glassTint
                )

                actionRow
                classificationCard
            }
            .padding(28)
        }
        .background(LuumTheme.pageGradient.opacity(0.46))
    }

    private var googleCalendarCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Google Agenda")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Conecte varias contas Google e escolha exatamente quais calendarios entram no luum.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(store.googleCalendarConnections.count)",
                    detail: "contas"
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Client ID")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                TextField(
                    "1234567890-abcdef.apps.googleusercontent.com",
                    text: Binding(
                        get: { store.googleCalendarClientID },
                        set: { store.updateGoogleCalendarClientID($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Text("Client secret opcional")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                SecureField(
                    "Opcional para apps desktop",
                    text: Binding(
                        get: { store.googleCalendarClientSecret },
                        set: { store.updateGoogleCalendarClientSecret($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }

            if let message = store.googleCalendarStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Os tokens OAuth ficam guardados no Keychain deste Mac e nao entram no backup em nuvem.")
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Adicionar conta Google") {
                    store.connectGoogleCalendar()
                }
                .buttonStyle(.glassProminent)
                .disabled(!store.isGoogleCalendarConfigured || store.isConnectingGoogleCalendar)

                Button("Sincronizar todas") {
                    store.refreshGoogleCalendar()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.isGoogleCalendarConnected || store.isSyncingGoogleCalendar)

                Button("Desconectar tudo") {
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

            HStack(spacing: 16) {
                Link("Criar credenciais no Google Cloud", destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
                Link("Guia oficial para OAuth desktop", destination: URL(string: "https://developers.google.com/identity/protocols/oauth2/native-app")!)
                Link("Calendarios e eventos", destination: URL(string: "https://developers.google.com/calendar/api/concepts/events-calendars")!)
            }
            .font(.caption)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.14), cornerRadius: 30)
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
                Text("Retencao local: \(store.privacySettings.retentionDays) dias")
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
                    Text("Backup Firestore")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("O luum pode sincronizar preferencias, agenda configurada e resumos diarios usando a API deste projeto por cima do Firestore.")
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

            TextField("Endpoint da API", text: Binding(
                get: { store.cloudSyncSettings.endpointURL },
                set: { store.updateCloudSyncEndpointURL($0) }
            ))
            .textFieldStyle(.roundedBorder)

            TextField("Backup ID", text: Binding(
                get: { store.cloudSyncSettings.backupID },
                set: { store.updateCloudSyncBackupID($0) }
            ))
            .textFieldStyle(.roundedBorder)

            SecureField(store.hasCloudBackupSecret ? "Chave salva neste Mac. Digite uma nova para trocar." : "Chave de backup", text: $backupSecretDraft)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button("Salvar chave") {
                    store.updateCloudBackupSecret(backupSecretDraft)
                    backupSecretDraft = ""
                }
                .buttonStyle(.glassProminent)
                .disabled(backupSecretDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Sincronizar agora") {
                    store.syncCloudBackupNow()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.cloudSyncConfigured || store.isSyncingCloud)

                Button("Restaurar backup") {
                    store.restoreCloudBackup()
                }
                .buttonStyle(.bordered)
                .disabled(!store.cloudSyncConfigured || store.isSyncingCloud)
            }

            Toggle("Sincronizar categorias e regras", isOn: Binding(
                get: { store.cloudSyncSettings.syncCategoriesAndRules },
                set: { store.updateCloudSyncSyncCategories($0) }
            ))
            .toggleStyle(.switch)

            Toggle("Sincronizar resumos diarios", isOn: Binding(
                get: { store.cloudSyncSettings.syncDailySummaries },
                set: { store.updateCloudSyncSyncDailySummaries($0) }
            ))
            .toggleStyle(.switch)

            Toggle("Sincronizar atividades brutas", isOn: Binding(
                get: { store.cloudSyncSettings.syncRawActivities },
                set: { store.updateCloudSyncSyncRawActivities($0) }
            ))
            .toggleStyle(.switch)

            if let cloudSyncStatusMessage = store.cloudSyncStatusMessage {
                Text(cloudSyncStatusMessage)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("O backup sincroniza configuracoes e resumos. Tokens do Google e a chave do backup continuam locais no Keychain.")
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

            Button("Abrir pasta do historico") {
                SystemSettings.openActivityLogFolder()
            }
            .buttonStyle(.bordered)
        }
    }

    private var classificationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Classificacao inicial")
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
                Text("Calendarios incluidos")
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
