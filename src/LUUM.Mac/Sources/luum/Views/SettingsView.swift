import SwiftUI

struct SettingsView: View {
    @Bindable var store: ActivityStore

    @State private var notionTokenDraft = ""
    @State private var notionDataSourceDraft = ""
    @State private var outlookTokenDraft = ""
    @State private var clickUpTokenDraft = ""
    @State private var clickUpListDraft = ""
    @State private var linearTokenDraft = ""
    @State private var linearTeamDraft = ""
    @State private var workspaceSecretDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Preferencias",
                    title: "Centro de integracoes e distribuicao",
                    subtitle: "Concentre aqui Google, Notion, Outlook, ClickUp, Linear, Zapier e o setup corporativo real do luum."
                )

                integrationHubCard
                googleCalendarCard
                notionCalendarCard
                outlookCalendarCard
                clickUpCard
                linearCard
                zapierCard
                teamCard
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

    private var integrationHubCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mapa de integracoes")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Cada tile abaixo mostra o estado real das fontes de agenda, automacao e nuvem. O ideal e sair daqui com tudo em verde antes de distribuir o luum.")
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
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12), cornerRadius: 30)
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

    private var notionCalendarCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notion Calendar")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("O luum usa a API oficial do Notion sobre data sources com propriedades de data para trazer eventos e paginas para a agenda integrada.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(store.notionCalendarSettings.databaseIDs.count)",
                    detail: "fontes"
                )
            }

            Toggle("Ativar integracao do Notion", isOn: Binding(
                get: { store.notionCalendarSettings.isEnabled },
                set: { store.updateNotionCalendarEnabled($0) }
            ))
            .toggleStyle(.switch)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    TextField("Notion", text: Binding(
                        get: { store.notionCalendarSettings.workspaceLabel },
                        set: { store.updateNotionWorkspaceLabel($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Token da integracao")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    SecureField(
                        store.hasNotionToken ? "Token salvo neste Mac. Digite um novo para trocar." : "secret_xxxxx",
                        text: $notionTokenDraft
                    )
                    .textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 10) {
                Button("Salvar token") {
                    let value = notionTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.updateNotionToken(value)
                    notionTokenDraft = ""
                }
                .buttonStyle(.glassProminent)
                .disabled(notionTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if store.hasNotionToken {
                    Button("Remover token") {
                        store.updateNotionToken("")
                        notionTokenDraft = ""
                    }
                    .buttonStyle(.bordered)
                }

                Button("Sincronizar Notion") {
                    store.refreshNotionCalendar()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.notionCalendarSettings.isEnabled || !store.notionCalendarConfigured || store.isSyncingNotionCalendar)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Propriedade de data")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    TextField("Date", text: Binding(
                        get: { store.notionCalendarSettings.datePropertyName },
                        set: { store.updateNotionDatePropertyName($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Propriedade de titulo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    TextField("Name", text: Binding(
                        get: { store.notionCalendarSettings.titlePropertyName },
                        set: { store.updateNotionTitlePropertyName($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Data source IDs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 10) {
                    TextField("Cole a URL ou o ID do data source", text: $notionDataSourceDraft)
                        .textFieldStyle(.roundedBorder)

                    Button("Adicionar fonte") {
                        let value = notionDataSourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.addNotionDataSourceID(value)
                        notionDataSourceDraft = ""
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(notionDataSourceDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if store.notionCalendarSettings.databaseIDs.isEmpty {
                    Text("Nenhuma fonte adicionada ainda. Voce pode colar a URL completa do Notion que o luum extrai o ID automaticamente.")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.notionCalendarSettings.databaseIDs, id: \.self) { sourceID in
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.image")
                                    .foregroundStyle(LuumTheme.secondaryAccent)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(sourceID)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .textSelection(.enabled)

                                    Text("Fonte usada para extrair paginas e compromissos com propriedade de data.")
                                        .font(.caption2)
                                        .foregroundStyle(LuumTheme.textSecondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    store.removeNotionDataSourceID(sourceID)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.white.opacity(0.03))
                            )
                        }
                    }
                }
            }

            if let message = store.notionCalendarStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let lastSyncAt = store.notionCalendarLastSyncAt {
                Text("Ultimo sync do Notion: \(LuumFormatters.relativeTime(until: lastSyncAt)).")
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textMuted)
            }

            HStack(spacing: 16) {
                Link("API oficial do Notion", destination: URL(string: "https://developers.notion.com/reference/intro")!)
                Link("Consultar data source", destination: URL(string: "https://developers.notion.com/reference/query-a-data-source")!)
                Link("Ajuda do Notion Calendar", destination: URL(string: "https://www.notion.com/help/notion-calendar")!)
            }
            .font(.caption)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 30)
    }

    private var outlookCalendarCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Outlook Calendar")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Conecte o Microsoft Graph com um access token e escolha quais calendarios do Outlook entram na agenda integrada.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(store.outlookCalendarSettings.calendars.filter(\.isSelected).count)",
                    detail: "calendarios"
                )
            }

            Toggle("Ativar Outlook Calendar", isOn: Binding(
                get: { store.outlookCalendarSettings.isEnabled },
                set: { store.updateOutlookCalendarEnabled($0) }
            ))
            .toggleStyle(.switch)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace / label")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    TextField("Outlook", text: Binding(
                        get: { store.outlookCalendarSettings.workspaceLabel },
                        set: { store.updateOutlookWorkspaceLabel($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Access token")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    SecureField(
                        store.hasOutlookToken ? "Token salvo neste Mac. Digite outro para trocar." : "eyJ...",
                        text: $outlookTokenDraft
                    )
                    .textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 10) {
                Button("Salvar token") {
                    let value = outlookTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.updateOutlookToken(value)
                    outlookTokenDraft = ""
                }
                .buttonStyle(.glassProminent)
                .disabled(outlookTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Sincronizar Outlook") {
                    store.refreshOutlookCalendar()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.outlookCalendarSettings.isEnabled || !store.outlookCalendarConfigured || store.isSyncingOutlookCalendar)
            }

            if !store.outlookCalendarSettings.calendars.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Calendarios selecionados")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    ForEach(store.outlookCalendarSettings.calendars) { calendar in
                        Toggle(isOn: Binding(
                            get: { calendar.isSelected },
                            set: { store.setOutlookCalendarSelection(calendarID: calendar.id, isSelected: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(calendar.title)
                                    .foregroundStyle(.white)
                                Text(calendar.isPrimary ? "Principal" : "Outlook Calendar")
                                    .font(.caption2)
                                    .foregroundStyle(LuumTheme.textSecondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.white.opacity(0.03))
                        )
                    }
                }
            }

            if let message = store.outlookCalendarStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }

            HStack(spacing: 16) {
                Link("Microsoft Graph Calendar", destination: URL(string: "https://learn.microsoft.com/graph/api/resources/calendar?view=graph-rest-1.0")!)
                Link("Graph calendarView", destination: URL(string: "https://learn.microsoft.com/graph/api/calendar-list-calendarview?view=graph-rest-1.0")!)
            }
            .font(.caption)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12), cornerRadius: 30)
    }

    private var clickUpCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ClickUp")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Traga tarefas com prazo do ClickUp para a agenda integrada usando token real e List IDs.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(store.clickUpSettings.listIDs.count)",
                    detail: "listas"
                )
            }

            Toggle("Ativar ClickUp", isOn: Binding(
                get: { store.clickUpSettings.isEnabled },
                set: { store.updateClickUpEnabled($0) }
            ))
            .toggleStyle(.switch)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                TextField("Workspace label", text: Binding(
                    get: { store.clickUpSettings.workspaceLabel },
                    set: { store.updateClickUpWorkspaceLabel($0) }
                ))
                .textFieldStyle(.roundedBorder)

                SecureField(
                    store.hasClickUpToken ? "Token salvo neste Mac. Digite outro para trocar." : "pk_...",
                    text: $clickUpTokenDraft
                )
                .textFieldStyle(.roundedBorder)
            }

            TextField("Workspace ID (opcional)", text: Binding(
                get: { store.clickUpSettings.workspaceID },
                set: { store.updateClickUpWorkspaceID($0) }
            ))
            .textFieldStyle(.roundedBorder)

            Toggle("Incluir tarefas fechadas", isOn: Binding(
                get: { store.clickUpSettings.includeClosedTasks },
                set: { store.updateClickUpIncludeClosedTasks($0) }
            ))
            .toggleStyle(.switch)

            HStack(spacing: 10) {
                TextField("Cole um List ID", text: $clickUpListDraft)
                    .textFieldStyle(.roundedBorder)

                Button("Adicionar lista") {
                    let value = clickUpListDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.addClickUpListID(value)
                    clickUpListDraft = ""
                }
                .buttonStyle(.glassProminent)
                .disabled(clickUpListDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 10) {
                Button("Salvar token") {
                    let value = clickUpTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.updateClickUpToken(value)
                    clickUpTokenDraft = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(clickUpTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Sincronizar ClickUp") {
                    store.refreshClickUp()
                }
                .buttonStyle(.bordered)
                .disabled(!store.clickUpSettings.isEnabled || !store.clickUpConfigured || store.isSyncingClickUp)
            }

            if !store.clickUpSettings.listIDs.isEmpty {
                ChipListCard(
                    title: "Listas selecionadas",
                    items: store.clickUpSettings.listIDs,
                    tint: LuumTheme.hotPink
                ) { item in
                    store.removeClickUpListID(item)
                }
            }

            if let message = store.clickUpStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12), cornerRadius: 30)
    }

    private var linearCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Linear")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Puxe issues com prazo e ciclos do Linear usando API key real e Team IDs.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(store.linearSettings.teamIDs.count)",
                    detail: "times"
                )
            }

            Toggle("Ativar Linear", isOn: Binding(
                get: { store.linearSettings.isEnabled },
                set: { store.updateLinearEnabled($0) }
            ))
            .toggleStyle(.switch)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                TextField("Workspace label", text: Binding(
                    get: { store.linearSettings.workspaceLabel },
                    set: { store.updateLinearWorkspaceLabel($0) }
                ))
                .textFieldStyle(.roundedBorder)

                SecureField(
                    store.hasLinearToken ? "API key salva neste Mac. Digite outra para trocar." : "lin_api_...",
                    text: $linearTokenDraft
                )
                .textFieldStyle(.roundedBorder)
            }

            TextField("Workspace ID (opcional)", text: Binding(
                get: { store.linearSettings.workspaceID },
                set: { store.updateLinearWorkspaceID($0) }
            ))
            .textFieldStyle(.roundedBorder)

            Toggle("Incluir issues concluidas", isOn: Binding(
                get: { store.linearSettings.includeCompletedIssues },
                set: { store.updateLinearIncludeCompletedIssues($0) }
            ))
            .toggleStyle(.switch)

            HStack(spacing: 10) {
                TextField("Cole um Team ID", text: $linearTeamDraft)
                    .textFieldStyle(.roundedBorder)

                Button("Adicionar time") {
                    let value = linearTeamDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.addLinearTeamID(value)
                    linearTeamDraft = ""
                }
                .buttonStyle(.glassProminent)
                .disabled(linearTeamDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 10) {
                Button("Salvar API key") {
                    let value = linearTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.updateLinearToken(value)
                    linearTokenDraft = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(linearTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Sincronizar Linear") {
                    store.refreshLinear()
                }
                .buttonStyle(.bordered)
                .disabled(!store.linearSettings.isEnabled || !store.linearConfigured || store.isSyncingLinear)
            }

            if !store.linearSettings.teamIDs.isEmpty {
                ChipListCard(
                    title: "Times selecionados",
                    items: store.linearSettings.teamIDs,
                    tint: LuumTheme.secondaryAccent
                ) { item in
                    store.removeLinearTeamID(item)
                }
            }

            if let message = store.linearStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12), cornerRadius: 30)
    }

    private var zapierCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zapier")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Dispare automacoes reais a partir de bloqueios de foco, syncs de agenda e atualizacoes do ranking corporativo.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: store.zapierConfigured ? "Ready" : "URL",
                    detail: "webhook"
                )
            }

            Toggle("Ativar Zapier", isOn: Binding(
                get: { store.zapierSettings.isEnabled },
                set: { store.updateZapierEnabled($0) }
            ))
            .toggleStyle(.switch)

            TextField("Webhook URL do Zapier", text: Binding(
                get: { store.zapierSettings.webhookURL },
                set: { store.updateZapierWebhookURL($0) }
            ))
            .textFieldStyle(.roundedBorder)

            Toggle("Enviar eventos de foco", isOn: Binding(
                get: { store.zapierSettings.sendsFocusEvents },
                set: { store.updateZapierSendsFocusEvents($0) }
            ))
            .toggleStyle(.switch)

            Toggle("Enviar eventos de sincronizacao da agenda", isOn: Binding(
                get: { store.zapierSettings.sendsCalendarSyncEvents },
                set: { store.updateZapierSendsCalendarSyncEvents($0) }
            ))
            .toggleStyle(.switch)

            Toggle("Enviar eventos do ranking corporativo", isOn: Binding(
                get: { store.zapierSettings.sendsWorkspaceRankingEvents },
                set: { store.updateZapierSendsWorkspaceRankingEvents($0) }
            ))
            .toggleStyle(.switch)

            HStack(spacing: 10) {
                Button("Testar webhook") {
                    store.sendZapierTestEvent()
                }
                .buttonStyle(.glassProminent)
                .disabled(!store.zapierSettings.isEnabled || !store.zapierConfigured)
            }

            if let message = store.zapierStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }
        }
        .padding(22)
        .luumGlassCard(tint: ActivityCategory.work.glassTint, cornerRadius: 30)
    }

    private var teamCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Equipe e ranking")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Configure o workspace corporativo para sincronizar um ranking real entre pessoas da mesma empresa, sem depender mais do modo preview.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: store.teamRankingUsesPreviewData ? "Preview" : "Live",
                    detail: "ranking"
                )
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Empresa")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    TextField("Minha empresa", text: Binding(
                        get: { store.teamSettings.organizationName },
                        set: { store.updateTeamOrganizationName($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nome de exibicao")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    TextField("Voce", text: Binding(
                        get: { store.teamSettings.memberDisplayName },
                        set: { store.updateTeamMemberDisplayName($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Papel")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                TextField("Individual", text: Binding(
                    get: { store.teamSettings.roleLabel },
                    set: { store.updateTeamRoleLabel($0) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Toggle("Compartilhar metricas anonimizadas no workspace", isOn: Binding(
                get: { store.teamSettings.sharesAnonymousMetrics },
                set: { store.updateTeamSharesAnonymousMetrics($0) }
            ))
            .toggleStyle(.switch)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                TextField("Workspace ID", text: Binding(
                    get: { store.teamSettings.workspaceID },
                    set: { store.updateTeamWorkspaceID($0) }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("Member ID", text: Binding(
                    get: { store.teamSettings.workspaceMemberID },
                    set: { store.updateTeamWorkspaceMemberID($0) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            LabeledContent("API do workspace", value: FirebaseAuthService.defaultBaseURL)
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)

            SecureField(
                store.hasWorkspaceSecret ? "Chave salva neste Mac. Digite uma nova para trocar." : "Chave do workspace",
                text: $workspaceSecretDraft
            )
            .textFieldStyle(.roundedBorder)

            Toggle("Sincronizar ranking automaticamente", isOn: Binding(
                get: { store.teamSettings.automaticallySyncWorkspace },
                set: { store.updateTeamAutomaticallySyncWorkspace($0) }
            ))
            .toggleStyle(.switch)

            HStack(spacing: 10) {
                Button("Salvar chave") {
                    store.updateTeamWorkspaceSecret(workspaceSecretDraft)
                    workspaceSecretDraft = ""
                }
                .buttonStyle(.glassProminent)
                .disabled(workspaceSecretDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Sincronizar ranking") {
                    store.syncWorkspaceRankingNow()
                }
                .buttonStyle(.borderedProminent)
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
                    Text("Firebase / Firestore Sync")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("O luum pode sincronizar preferencias, ranking e resumos diarios usando a API deste projeto por cima do Firestore.")
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

            LabeledContent("API oficial", value: FirebaseAuthService.defaultBaseURL)
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)

            LabeledContent("Backup da conta", value: store.accountEmail.isEmpty ? "Entre com sua conta Luum" : store.accountEmail)
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)

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
            .disabled(!store.canUse(.rawActivityBackup))

            if let cloudSyncStatusMessage = store.cloudSyncStatusMessage {
                Text(cloudSyncStatusMessage)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("O backup usa seu login Firebase e sincroniza configuracoes sanitizadas e resumos. Tokens das integracoes continuam locais neste Mac.")
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

    private var activeIntegrationCount: Int {
        [
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

    private func integrationSnapshot(for kind: IntegrationKind) -> IntegrationSnapshot {
        switch kind {
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
                    detail: "Client ID configurado",
                    tint: LuumTheme.secondaryAccent
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Pendente",
                detail: "Falta configurar OAuth",
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

            if store.notionCalendarSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Ative token e data source",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integracao opcional",
                tint: LuumTheme.textMuted
            )
        case .outlookCalendar:
            if store.outlookCalendarSettings.isEnabled && store.outlookCalendarConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: "\(store.outlookCalendarSettings.calendars.filter(\.isSelected).count) calendario(s) sincronizados",
                    tint: LuumTheme.electricBlue
                )
            }

            if store.outlookCalendarSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Token pendente ou sem sync",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integracao opcional",
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

            if store.clickUpSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Token ou listas pendentes",
                    tint: LuumTheme.secondaryAccent
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integracao opcional",
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

            if store.linearSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "API key ou Team IDs pendentes",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integracao opcional",
                tint: LuumTheme.textMuted
            )
        case .zapier:
            if store.zapierSettings.isEnabled && store.zapierConfigured {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Ativo",
                    detail: "Webhook pronto para automacoes",
                    tint: ActivityCategory.work.tint
                )
            }

            if store.zapierSettings.isEnabled {
                return IntegrationSnapshot(
                    kind: kind,
                    status: "Parcial",
                    detail: "Webhook pendente",
                    tint: LuumTheme.hotPink
                )
            }

            return IntegrationSnapshot(
                kind: kind,
                status: "Desativado",
                detail: "Integracao opcional",
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
                    detail: "Endpoint ou chave pendente",
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
