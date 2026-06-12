import SwiftUI

struct AgendaView: View {
    let store: ActivityStore
    let selectedDay: Date
    let agenda: AgendaSummary

    private var agendaSections: [(title: String, events: [CalendarAgendaItem])] {
        let calendar = Calendar.autoupdatingCurrent

        return Dictionary(grouping: agenda.events) { event in
            calendar.startOfDay(for: event.startDate)
        }
        .map { day, events in
            (
                title: day.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                events: events.sorted { $0.startDate < $1.startDate }
            )
        }
        .sorted { lhs, rhs in
            lhs.events.first?.startDate ?? .distantPast < rhs.events.first?.startDate ?? .distantPast
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LuumSectionHeader(
                    eyebrow: "Agenda",
                    title: "Agenda integrada",
                    subtitle: "Cruze Google, Notion, Outlook, ClickUp e Linear numa mesma linha do tempo para comparar melhor plano, contexto e execucao."
                )

                agendaStatusCard

                if !agenda.connections.isEmpty || !agenda.notionSources.isEmpty || !agenda.outlookSources.isEmpty || !agenda.clickUpSources.isEmpty || !agenda.linearSources.isEmpty {
                    sourcesCard
                }

                if agenda.events.isEmpty {
                    emptyAgendaCard
                } else {
                    upcomingCard

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(agendaSections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(section.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(LuumTheme.textMuted)
                                    .tracking(1.2)

                                ForEach(section.events) { event in
                                    AgendaRow(event: event)
                                }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }

    private var agendaStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(agenda.isConnected ? "Fontes conectadas" : "Setup da agenda")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(statusDescription)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                HStack(spacing: 10) {
                    if store.isGoogleCalendarConnected || store.notionCalendarSettings.isEnabled || store.outlookCalendarSettings.isEnabled || store.clickUpSettings.isEnabled || store.linearSettings.isEnabled {
                        Button("Sincronizar tudo") {
                            store.refreshIntegratedCalendars(for: selectedDay)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(
                            (store.isSyncingGoogleCalendar && store.isSyncingNotionCalendar && store.isSyncingOutlookCalendar && store.isSyncingClickUp && store.isSyncingLinear)
                                || (!store.isGoogleCalendarConnected && !store.notionCalendarSettings.isEnabled && !store.outlookCalendarSettings.isEnabled && !store.clickUpSettings.isEnabled && !store.linearSettings.isEnabled)
                        )
                    } else {
                        Button("Conectar Google Agenda") {
                            store.connectGoogleCalendar(for: selectedDay)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(store.isConnectingGoogleCalendar)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if let message = store.googleCalendarStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let message = store.notionCalendarStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let message = store.outlookCalendarStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let message = store.clickUpStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let message = store.linearStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12))
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fontes ativas")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ForEach(agenda.connections) { connection in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(LuumTheme.electricBlue)

                            Text("Google Calendar")
                                .foregroundStyle(.white)
                                .font(.headline)
                        }

                        Text(connection.profile.name)
                            .foregroundStyle(.white.opacity(0.9))
                            .font(.subheadline.weight(.semibold))

                        Text(connection.profile.email)
                            .foregroundStyle(LuumTheme.textSecondary)
                            .font(.caption)

                        Text("\(connection.selectedCalendars.count) calendario(s) selecionado(s)")
                            .foregroundStyle(LuumTheme.electricBlue)
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(0.02))
                    )
                }

                ForEach(agenda.notionSources) { source in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text.image")
                                .foregroundStyle(LuumTheme.secondaryAccent)

                            Text("Notion")
                                .foregroundStyle(.white)
                                .font(.headline)
                        }

                        Text(source.workspaceLabel)
                            .foregroundStyle(.white.opacity(0.9))
                            .font(.subheadline.weight(.semibold))

                        Text("\(source.dataSourceCount) data source(s)")
                            .foregroundStyle(LuumTheme.secondaryAccent)
                            .font(.caption.weight(.semibold))

                        if let lastSyncAt = source.lastSyncAt {
                            Text("sync \(LuumFormatters.relativeTime(until: lastSyncAt))")
                                .foregroundStyle(LuumTheme.textSecondary)
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(0.02))
                    )
                }

                ForEach(agenda.outlookSources) { source in
                    sourceCard(
                        systemImage: "envelope.badge",
                        label: "Outlook",
                        title: source.workspaceLabel,
                        subtitle: source.accountEmail,
                        detail: "\(source.selectedCalendars.count) calendario(s) selecionado(s)",
                        detailTint: LuumTheme.electricBlue,
                        lastSyncAt: source.lastSyncAt
                    )
                }

                ForEach(agenda.clickUpSources) { source in
                    sourceCard(
                        systemImage: "checkmark.seal",
                        label: "ClickUp",
                        title: source.title,
                        subtitle: "\(source.itemCount) tarefa(s) com prazo",
                        detail: "\(source.configuredSourceCount) lista(s) configurada(s)",
                        detailTint: LuumTheme.hotPink,
                        lastSyncAt: source.lastSyncAt
                    )
                }

                ForEach(agenda.linearSources) { source in
                    sourceCard(
                        systemImage: "line.3.horizontal.decrease.circle",
                        label: "Linear",
                        title: source.title,
                        subtitle: "\(source.itemCount) issue(s) com prazo",
                        detail: "\(source.configuredSourceCount) time(s) configurado(s)",
                        detailTint: LuumTheme.secondaryAccent,
                        lastSyncAt: source.lastSyncAt
                    )
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 30)
    }

    private var emptyAgendaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(emptyStateTitle)
                .font(.headline)
                .foregroundStyle(.white)

            Text(emptyStateDescription)
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link("OAuth desktop do Google", destination: URL(string: "https://developers.google.com/identity/protocols/oauth2/native-app")!)
                    .foregroundStyle(LuumTheme.electricBlue)

                Link("API do Notion", destination: URL(string: "https://developers.notion.com/reference/intro")!)
                    .foregroundStyle(LuumTheme.secondaryAccent)

                Link("Microsoft Graph", destination: URL(string: "https://learn.microsoft.com/graph/api/resources/calendar?view=graph-rest-1.0")!)
                    .foregroundStyle(LuumTheme.hotPink)
            }
            .font(.caption)
        }
        .padding(24)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.16))
    }

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Proximo compromisso")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.64))

            if let nextEvent = agenda.nextEvent {
                Text(nextEvent.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(nextEvent.isAllDay ? "Dia inteiro" : LuumFormatters.timeRange(start: nextEvent.startDate, end: nextEvent.endDate))
                    .foregroundStyle(LuumTheme.electricBlue)
                    .font(.headline)

                Text("\(nextEvent.accountLabel) • \(nextEvent.calendarTitle)")
                    .foregroundStyle(LuumTheme.textSecondary)
            }
        }
        .padding(24)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.18), cornerRadius: 34)
    }

    private var statusDescription: String {
        if agenda.isConnected {
            return "\(agenda.connectedAccountCount) fonte(s) conectada(s) e \(agenda.selectedCalendarCount) calendarios/listas/fontes ativos neste Mac. O luum mostra o dia selecionado e os proximos 3 dias."
        }

        if store.isGoogleCalendarConfigured || store.notionCalendarSettings.isEnabled || store.outlookCalendarSettings.isEnabled || store.clickUpSettings.isEnabled || store.linearSettings.isEnabled {
            return "O setup comecou. Falta concluir pelo menos uma das fontes para puxar eventos reais para a agenda integrada."
        }

        return "Adicione Google, Notion, Outlook, ClickUp e/ou Linear nas preferencias para liberar a comparacao entre o planejado e o tempo real."
    }

    private var emptyStateTitle: String {
        if !agenda.isConfigured {
            return "A agenda integrada ainda nao foi configurada."
        }

        if !agenda.isConnected {
            return "A configuracao esta pronta, falta conectar."
        }

        return "Sem compromissos na janela atual."
    }

    private var emptyStateDescription: String {
        if !agenda.isConfigured {
            return "Nas preferencias do luum voce pode configurar OAuth desktop do Google e tambem adicionar data sources do Notion com propriedade de data."
        }

        if !agenda.isConnected {
            return "Depois de conectar, o luum lista calendarios e fontes para voce decidir o que entra na timeline integrada."
        }

        return "Troque a data no painel principal ou sincronize novamente para verificar o dia escolhido e os proximos 3 dias."
    }
}

private extension AgendaView {
    func sourceCard(
        systemImage: String,
        label: String,
        title: String,
        subtitle: String,
        detail: String,
        detailTint: Color,
        lastSyncAt: Date?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(detailTint)

                Text(label)
                    .foregroundStyle(.white)
                    .font(.headline)
            }

            Text(title)
                .foregroundStyle(.white.opacity(0.9))
                .font(.subheadline.weight(.semibold))

            Text(subtitle)
                .foregroundStyle(LuumTheme.textSecondary)
                .font(.caption)

            Text(detail)
                .foregroundStyle(detailTint)
                .font(.caption.weight(.semibold))

            if let lastSyncAt {
                Text("sync \(LuumFormatters.relativeTime(until: lastSyncAt))")
                    .foregroundStyle(LuumTheme.textSecondary)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.02))
        )
    }
}

private struct AgendaRow: View {
    let event: CalendarAgendaItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: event.calendarColorHex) ?? LuumTheme.electricBlue, LuumTheme.accent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 8, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(event.isAllDay ? "Dia inteiro" : LuumFormatters.timeRange(start: event.startDate, end: event.endDate))
                    .foregroundStyle(LuumTheme.electricBlue)
                    .font(.caption.weight(.semibold))

                Text("\(event.accountLabel) • \(event.calendarTitle)")
                    .foregroundStyle(LuumTheme.textSecondary)
                    .font(.caption)

                if let location = event.location {
                    Text(location)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .font(.caption)
                }
            }

            Spacer()

            if let htmlLink = event.htmlLink, let url = URL(string: htmlLink) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.white.opacity(0.74))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .luumGlassCard(tint: (Color(hex: event.calendarColorHex) ?? LuumTheme.electricBlue).opacity(0.12), cornerRadius: 28, shadowOpacity: 0.16)
    }
}

private extension Color {
    init?(hex: String?) {
        guard let hex else { return nil }
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }

        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
