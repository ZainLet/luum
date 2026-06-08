import Charts
import SwiftUI

struct DashboardView: View {
    let store: ActivityStore
    @Binding var selectedDay: Date
    let summary: DailySummary
    let agenda: AgendaSummary
    let openAgenda: () -> Void
    let openApps: () -> Void
    let openWebsites: () -> Void
    let openTeam: () -> Void
    let openCategories: () -> Void
    let openFocus: () -> Void
    let openReports: () -> Void
    let openSearch: () -> Void
    let openSettings: () -> Void

    private var leadingCategory: CategoryBreakdown? {
        summary.categoryBreakdown.first
    }

    private var trackedVersusPlanned: String {
        guard agenda.plannedTime > 0 else {
            return "Sem agenda"
        }

        return LuumFormatters.percentage(summary.totalTrackedTime, over: agenda.plannedTime)
    }

    private var agendaPreviewEvents: [CalendarAgendaItem] {
        agenda.focusedEvents.isEmpty ? agenda.events : agenda.focusedEvents
    }

    private var nextAgendaLabel: String {
        guard let nextEvent = agenda.nextEvent else {
            return agenda.isConnected ? "Nenhum compromisso para este dia." : "Conecte Google, Notion, Outlook, ClickUp ou Linear para comparar o plano com o uso real."
        }

        if nextEvent.isAllDay {
            return "Dia inteiro"
        }

        return LuumFormatters.timeRange(start: nextEvent.startDate, end: nextEvent.endDate)
    }

    private var greetingTitle: String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12:
            return "Bom dia, Luum"
        case 12 ..< 18:
            return "Boa tarde, Luum"
        default:
            return "Boa noite, Luum"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                contextHeader

                if store.needsOnboarding {
                    onboardingCard
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        metricsStrip
                        quickActionStrip
                        timelineBoard
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(spacing: 14) {
                        agendaCard
                        performanceCard
                        liveSignalsCard
                        topBreakdownsCard
                    }
                    .frame(width: 312)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Onboarding rapido")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Deixe o luum pronto em poucos passos para que o monitoramento, a agenda e os lembretes funcionem sem surpresas.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("Fechar checklist") {
                    store.completeOnboarding()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(LuumTheme.textSecondary)
            }

            VStack(spacing: 10) {
                ForEach(store.onboardingChecklist) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(item.isDone ? LuumTheme.electricBlue : LuumTheme.textMuted)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .foregroundStyle(.white)
                                .font(.subheadline.weight(.semibold))

                            Text(item.detail)
                                .foregroundStyle(LuumTheme.textSecondary)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        if let actionTitle = item.actionTitle {
                            Button(actionTitle) {
                                handleOnboarding(itemID: item.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(0.03))
                    )
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.14), cornerRadius: 32)
    }

    private var contextHeader: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                LuumSectionHeader(
                    eyebrow: "Hoje",
                    title: greetingTitle,
                    subtitle: "Revise captura, agenda e sinais importantes do dia."
                )

                HStack(spacing: 10) {
                    StatusPill(
                        title: store.isMonitoring ? "Captura ativa" : "Captura pausada",
                        detail: store.currentActivityCategory?.title ?? "Monitoramento local",
                        tint: store.currentActivityCategory?.tint ?? LuumTheme.accent
                    )

                    StatusPill(
                        title: agenda.isConnected ? "Agenda conectada" : "Agenda desconectada",
                        detail: agenda.isConnected ? "\(agenda.selectedCalendarCount) fonte(s)" : "Agenda integrada",
                        tint: agenda.isConnected ? LuumTheme.secondaryAccent : LuumTheme.hotPink
                    )

                    StatusPill(
                        title: LuumFormatters.dayLabel(selectedDay),
                        detail: "dia selecionado",
                        tint: LuumTheme.electricBlue
                    )

                    if store.focusShieldProfilesCount > 0 {
                        StatusPill(
                            title: store.currentFocusBlockMatch == nil ? "Escudo pronto" : "Bloqueio ativo",
                            detail: store.currentFocusBlockMatch?.title ?? "\(store.focusShieldProfilesCount) perfil(is)",
                            tint: store.currentFocusBlockMatch == nil ? LuumTheme.hotPink : LuumTheme.electricBlue
                        )
                    }
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 14) {
                DashboardDatePanel(selectedDay: $selectedDay)
                summarySnapshotCard
                    .frame(width: 330)
            }
        }
        .padding(20)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.10), cornerRadius: 18, shadowOpacity: 0.08)
    }

    private var summarySnapshotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SnapshotLine(
                eyebrow: "Agora",
                title: store.currentActivityTitle,
                detail: store.currentActivityCategory?.title ?? "Aguardando nova atividade",
                tint: store.currentActivityCategory?.tint ?? LuumTheme.accent
            )

            Divider()
                .overlay(.white.opacity(0.06))

            SnapshotLine(
                eyebrow: "Proxima agenda",
                title: agenda.nextEvent?.title ?? "Sem compromisso em fila",
                detail: nextAgendaLabel,
                tint: LuumTheme.electricBlue
            )
        }
        .padding(16)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.10), cornerRadius: 16, shadowOpacity: 0.08)
    }

    private var metricsStrip: some View {
        HStack(spacing: 12) {
            OverviewMetricCard(
                title: "Tempo capturado",
                value: LuumFormatters.duration(summary.totalTrackedTime),
                detail: "historico do dia",
                tint: LuumTheme.accent,
                action: openApps
            )

            OverviewMetricCard(
                title: "Tempo planejado",
                value: LuumFormatters.duration(agenda.plannedTime),
                detail: "agenda do dia",
                tint: LuumTheme.secondaryAccent,
                action: openAgenda
            )

            OverviewMetricCard(
                title: "Cobertura",
                value: trackedVersusPlanned,
                detail: "real vs agenda",
                tint: LuumTheme.electricBlue,
                action: openAgenda
            )

            OverviewMetricCard(
                title: "Categoria lider",
                value: leadingCategory?.category.title ?? "Sem dados",
                detail: leadingCategory.map { LuumFormatters.duration($0.duration) } ?? "aguardando uso",
                tint: leadingCategory?.category.tint ?? LuumTheme.hotPink,
                action: openCategories
            )
        }
    }

    private var quickActionStrip: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            QuickActionCard(
                title: "Busca global",
                detail: "encontre qualquer contexto",
                symbol: "magnifyingglass",
                tint: LuumTheme.accent,
                action: openSearch
            )

            QuickActionCard(
                title: "Foco e metas",
                detail: "acompanhe limites, metas e bloqueios",
                symbol: "target",
                tint: LuumTheme.electricBlue,
                action: openFocus
            )

            QuickActionCard(
                title: "Relatorio semanal",
                detail: "veja tendencias e exporte",
                symbol: "chart.xyaxis.line",
                tint: LuumTheme.hotPink,
                action: openReports
            )

            QuickActionCard(
                title: "Equipe e ranking",
                detail: store.teamRankingUsesPreviewData ? "ative o workspace real" : "ranking ao vivo da empresa",
                symbol: "person.3.fill",
                tint: LuumTheme.secondaryAccent,
                action: openTeam
            )
        }
    }

    private var timelineBoard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Linha do tempo")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Atividade real e agenda ficam lado a lado para voce entender o dia sem blocos sobrepostos nem excesso de informacao.")
                        .foregroundStyle(LuumTheme.textSecondary)
                }

                Spacer()

                Button("Apps e sites") {
                    openApps()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(LuumTheme.textSecondary)

                HStack(spacing: 8) {
                    LegendChip(title: "Atividade real", tint: LuumTheme.accent)
                    LegendChip(title: "Agenda integrada", tint: LuumTheme.electricBlue)
                }
            }

            TimelineScene(store: store, activities: summary.timelineActivities, agendaItems: agenda.events)
                .frame(height: 620)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 34)
    }

    private var agendaCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Agenda")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button("Ver agenda") {
                    openAgenda()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(LuumTheme.textSecondary)

                if let lastSyncAt = agenda.lastSyncAt {
                    Text("sync \(LuumFormatters.relativeTime(until: lastSyncAt))")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textMuted)
                }
            }

            if !agenda.isConfigured {
                Text("Adicione Google e/ou Notion nas preferencias para liberar a comparacao com a agenda.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else if !agenda.isConnected {
                Text("A configuracao esta pronta. Falta sincronizar pelo menos uma fonte para puxar os compromissos.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else if agenda.events.isEmpty {
                Text("Nenhum compromisso encontrado entre a data escolhida e os proximos 3 dias.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                if !agenda.hasEventsInFocusDay {
                    Text("Sem eventos no dia selecionado. Mostrando apenas os proximos compromissos dentro de 3 dias.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let nextEvent = agenda.nextEvent {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Proximo bloco")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LuumTheme.textMuted)

                        Text(nextEvent.title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(nextAgendaLabel)
                            .foregroundStyle(LuumTheme.electricBlue)
                            .font(.subheadline.weight(.semibold))

                        Text("\(nextEvent.accountLabel) • \(nextEvent.calendarTitle)")
                            .foregroundStyle(LuumTheme.textSecondary)
                            .font(.caption)
                    }
                    .padding(16)
                    .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.16), cornerRadius: 24, shadowOpacity: 0.14)
                }

                VStack(spacing: 10) {
                    ForEach(agendaPreviewEvents.prefix(4)) { event in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill((Color(hex: event.calendarColorHex) ?? LuumTheme.electricBlue).gradient)
                                .frame(width: 4, height: 38)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .foregroundStyle(.white)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)

                                Text(event.isAllDay ? "Dia inteiro" : LuumFormatters.timeRange(start: event.startDate, end: event.endDate))
                                    .foregroundStyle(LuumTheme.textSecondary)
                                    .font(.caption)

                                Text(event.startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                    .foregroundStyle(LuumTheme.textMuted)
                                    .font(.caption2)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LuumTheme.panelFill)
                        )
                    }
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12))
    }

    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Categorias")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button("Editar") {
                    openCategories()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(LuumTheme.textSecondary)
            }

            if summary.categoryBreakdown.isEmpty {
                Text("Sem dados suficientes para mostrar o mix do dia.")
                    .foregroundStyle(LuumTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Chart(summary.categoryBreakdown) { bucket in
                    SectorMark(
                        angle: .value("Tempo", bucket.duration),
                        innerRadius: .ratio(0.64),
                        angularInset: 2
                    )
                    .foregroundStyle(bucket.category.tint.gradient)
                }
                .frame(height: 190)

                VStack(spacing: 10) {
                    ForEach(summary.categoryBreakdown.prefix(5)) { bucket in
                        HStack {
                            Circle()
                                .fill(bucket.category.tint)
                                .frame(width: 10, height: 10)

                            Text(bucket.category.title)
                                .foregroundStyle(.white.opacity(0.9))

                            Spacer()

                            Text(LuumFormatters.duration(bucket.duration))
                                .foregroundStyle(bucket.category.tint)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12))
    }

    private var liveSignalsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Resumo rapido")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button("Preferencias") {
                    openSettings()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(LuumTheme.textSecondary)
            }

            MetricLine(
                title: "Tempo capturado",
                value: LuumFormatters.duration(summary.totalTrackedTime),
                detail: "historico local do dia"
            )

            MetricLine(
                title: "Tempo planejado",
                value: LuumFormatters.duration(agenda.plannedTime),
                detail: "compromissos do dia selecionado"
            )

            MetricLine(
                title: "Cobertura",
                value: trackedVersusPlanned,
                detail: "relacao entre uso real e plano"
            )

            if let leadingCategory {
                MetricLine(
                    title: "Categoria lider",
                    value: leadingCategory.category.title,
                    detail: LuumFormatters.duration(leadingCategory.duration)
                )
            }

            if store.focusShieldProfilesCount > 0 {
                MetricLine(
                    title: "Escudo de foco",
                    value: store.currentFocusBlockMatch?.title ?? "Armado",
                    detail: store.focusShieldStatusMessage ?? "\(store.focusShieldProfilesCount) perfil(is) com bloqueio configurado"
                )
            }

            if let message = store.lastReminderStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14))
    }

    private var topBreakdownsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Apps e sites")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 12) {
                    Button("Apps") {
                        openApps()
                    }
                    .buttonStyle(.borderless)

                    Button("Sites") {
                        openWebsites()
                    }
                    .buttonStyle(.borderless)
                }
                .foregroundStyle(LuumTheme.textSecondary)
            }

            BreakdownHighlight(
                title: "Top app",
                item: summary.appBreakdown.first,
                emptyState: "Nenhum app consolidado ainda.",
                tint: LuumTheme.accent
            )

            BreakdownHighlight(
                title: "Top site",
                item: summary.websiteBreakdown.first,
                emptyState: "Nenhum site consolidado ainda.",
                tint: LuumTheme.electricBlue
            )

            if let automationStatusMessage = store.automationStatusMessage {
                Text(automationStatusMessage)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12))
    }

    private func handleOnboarding(itemID: String) {
        switch itemID {
        case "google-client", "google-account":
            openAgenda()
            store.handleOnboardingAction(itemID, day: selectedDay)
        case "browser-data":
            SystemSettings.openAutomationPrivacy()
        case "notifications":
            openSettings()
            store.handleOnboardingAction(itemID, day: selectedDay)
        default:
            store.handleOnboardingAction(itemID, day: selectedDay)
        }
    }
}

private struct TimelineScene: View {
    let store: ActivityStore
    let activities: [ResolvedActivitySample]
    let agendaItems: [CalendarAgendaItem]

    private var displayedActivities: [ResolvedActivitySample] {
        Array(activities.prefix(120))
    }

    private var displayedAgendaItems: [CalendarAgendaItem] {
        Array(agendaItems.prefix(80))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            TimelineColumnCard(title: "Atividade real", icon: "waveform.path.ecg.rectangle.fill", tint: LuumTheme.accent) {
                if activities.isEmpty {
                    TimelineEmptyState(text: "Nenhuma atividade capturada neste dia.")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if activities.count > displayedActivities.count {
                                TimelineLimitNotice(
                                    text: "Mostrando \(displayedActivities.count) blocos mais recentes de \(activities.count)."
                                )
                            }

                            ForEach(activitySections, id: \.title) { section in
                                TimelineSectionHeader(title: section.title)

                                ForEach(section.activities) { activity in
                                    EditableActivityRow(store: store, activity: activity, compact: false)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }

            TimelineColumnCard(title: "Agenda", icon: "calendar.badge.clock", tint: LuumTheme.electricBlue) {
                if agendaItems.isEmpty {
                    TimelineEmptyState(text: "Nenhum compromisso das fontes integradas para o dia selecionado ou para os proximos 3 dias.")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if agendaItems.count > displayedAgendaItems.count {
                                TimelineLimitNotice(
                                    text: "Mostrando \(displayedAgendaItems.count) eventos mais recentes de \(agendaItems.count)."
                                )
                            }

                            ForEach(agendaSections, id: \.sortDate) { section in
                                TimelineSectionHeader(title: section.title)

                                ForEach(section.events) { event in
                                    AgendaTimelineRow(event: event)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private var activitySections: [ActivityTimelineSection] {
        Dictionary(grouping: displayedActivities) { activity in
            activity.startDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)))
        }
        .map { key, value in
            ActivityTimelineSection(title: "\(key):00", activities: value.sorted { $0.startDate > $1.startDate })
        }
        .sorted { $0.activities.first?.startDate ?? .distantPast > $1.activities.first?.startDate ?? .distantPast }
    }

    private var agendaSections: [AgendaTimelineSection] {
        let calendar = Calendar.autoupdatingCurrent

        return Dictionary(grouping: displayedAgendaItems) { event in
            calendar.startOfDay(for: event.startDate)
        }
        .map { day, value in
            AgendaTimelineSection(
                title: day.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                sortDate: day,
                events: value.sorted { $0.startDate < $1.startDate }
            )
        }
        .sorted { $0.sortDate < $1.sortDate }
    }
}

private struct ActivityTimelineSection {
    let title: String
    let activities: [ResolvedActivitySample]
}

private struct AgendaTimelineSection {
    let title: String
    let sortDate: Date
    let events: [CalendarAgendaItem]
}

private struct TimelineColumnCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LuumTheme.panelFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(tint.opacity(0.14))
        }
    }
}

private struct TimelineSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.58))
            .padding(.top, 8)
    }
}

private struct TimelineEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(LuumTheme.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 8)
    }
}

private struct TimelineLimitNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(LuumTheme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.03))
            )
    }
}

private struct EditableActivityRow: View {
    @Bindable var store: ActivityStore
    let activity: ResolvedActivitySample
    let compact: Bool

    @State private var showsEditor = false

    var body: some View {
        Button {
            showsEditor = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LuumFormatters.timeRange(start: activity.startDate, end: activity.endDate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(LuumFormatters.duration(activity.duration))
                        .font(.caption2)
                        .foregroundStyle(LuumTheme.textSecondary)
                }
                .frame(width: 108, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.pageTitle ?? activity.applicationName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(activity.webDomain ?? activity.applicationName)
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .lineLimit(1)

                    Label(activity.category.title, systemImage: activity.category.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(activity.category.tint)

                    if activity.isManuallyCategorized {
                        Text("Ajuste manual")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                if compact {
                    Text(LuumFormatters.duration(activity.duration))
                        .foregroundStyle(.white.opacity(0.92))
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(compact ? 0.04 : 0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(activity.category.tint.opacity(0.14))
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Menu("Reclassificar bloco") {
                ForEach(store.categories) { category in
                    Button {
                        store.overrideActivityCategory(sampleID: activity.id, categoryID: category.id)
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                    }
                }
            }

            if let domain = activity.webDomain {
                Menu("Aprender site") {
                    ForEach(store.categories) { category in
                        Button(category.title) {
                            store.assignCategory(toDomain: domain, categoryID: category.id)
                        }
                    }
                }
            }

            Menu("Aprender app") {
                ForEach(store.categories) { category in
                    Button(category.title) {
                        store.assignCategory(toApplication: activity.applicationName, categoryID: category.id)
                    }
                }
            }

            Divider()

            Button(activity.sample.isHidden ? "Voltar a mostrar bloco" : "Ocultar bloco") {
                store.setActivityHidden(sampleID: activity.id, isHidden: !activity.sample.isHidden)
            }

            Button("Remover ajuste manual") {
                store.resetActivityEdits(sampleID: activity.id)
            }
            .disabled(!activity.isManuallyCategorized && !activity.sample.isHidden)
        }
        .sheet(isPresented: $showsEditor) {
            TimelineActivityEditor(store: store, activity: activity)
        }
    }
}

private struct AgendaTimelineRow: View {
    let event: CalendarAgendaItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.isAllDay ? "Dia inteiro" : LuumFormatters.timeRange(start: event.startDate, end: event.endDate))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)

                Text(LuumFormatters.duration(event.duration))
                    .font(.caption2)
                    .foregroundStyle(LuumTheme.textSecondary)
            }
            .frame(width: 108, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let location = event.location {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                }

                Text("\(event.accountLabel) • \(event.calendarTitle)")
                    .font(.caption2)
                    .foregroundStyle(LuumTheme.textMuted)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }
}

private struct BreakdownHighlight: View {
    let title: String
    let item: UsageBreakdownItem?
    let emptyState: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.54))

            if let item {
                Text(item.label)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(item.secondaryLabel ?? LuumFormatters.duration(item.duration))
                    .foregroundStyle(LuumTheme.textSecondary)
                    .font(.subheadline)

                Text(LuumFormatters.duration(item.duration))
                    .foregroundStyle(tint)
                    .font(.caption.weight(.semibold))
            } else {
                Text(emptyState)
                    .foregroundStyle(LuumTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LuumTheme.panelFill)
        )
    }
}

private struct StatusPill: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.16))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.07))
        }
    }
}

private struct LegendChip: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)

            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.74))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(LuumTheme.panelFill)
        )
    }
}

private struct MetricLine: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(detail)
                .font(.caption)
                .foregroundStyle(LuumTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LuumTheme.panelFill)
        )
    }
}

private struct QuickActionCard: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))

                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.white)
                        .font(.subheadline.weight(.semibold))

                    Text(detail)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .font(.caption)
                }

                Spacer()
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .luumGlassCard(tint: tint.opacity(0.14), cornerRadius: 26, shadowOpacity: 0.1)
    }
}

private struct OverviewMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LuumTheme.textMuted)
                    .tracking(1.1)

                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(tint.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .buttonStyle(.plain)
        .luumGlassCard(tint: tint.opacity(0.16), cornerRadius: 26, shadowOpacity: 0.14)
    }
}

private struct DashboardDatePanel: View {
    @Binding var selectedDay: Date

    var body: some View {
        HStack(spacing: 10) {
            Button {
                shiftDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LuumTheme.textSecondary)

                DatePicker("Dia", selection: $selectedDay, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(width: 122)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(LuumTheme.panelFill)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(LuumTheme.surfaceOutline)
            }

            Button("Hoje") {
                selectedDay = Date()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(LuumTheme.textSecondary)

            Button {
                shiftDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
    }

    private func shiftDay(by value: Int) {
        selectedDay = Calendar.autoupdatingCurrent.date(byAdding: .day, value: value, to: selectedDay) ?? selectedDay
    }
}

private struct SnapshotLine: View {
    let eyebrow: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)

                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LuumTheme.textMuted)
                    .tracking(1.1)
            }

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(detail)
                .font(.caption)
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension Color {
    init?(hex: String?) {
        guard let hex else { return nil }
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
