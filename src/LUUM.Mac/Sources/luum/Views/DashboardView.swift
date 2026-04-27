import Charts
import SwiftUI

struct DashboardView: View {
    let store: ActivityStore
    let selectedDay: Date
    let summary: DailySummary
    let agenda: AgendaSummary

    private var leadingCategory: CategoryBreakdown? {
        summary.categoryBreakdown.first
    }

    private var trackedVersusPlanned: String {
        LuumFormatters.percentage(summary.totalTrackedTime, over: max(agenda.plannedTime, 1))
    }

    private var nextAgendaLabel: String {
        guard let nextEvent = agenda.nextEvent else {
            return agenda.isConnected ? "Nenhum compromisso para este dia." : "Conecte a Google Agenda para ver a proxima reuniao aqui."
        }

        if nextEvent.isAllDay {
            return "\(nextEvent.title) • dia inteiro"
        }

        return "\(nextEvent.title) • \(LuumFormatters.timeRange(start: nextEvent.startDate, end: nextEvent.endDate))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroPanel

                HStack(alignment: .top, spacing: 22) {
                    VStack(spacing: 22) {
                        timelineBoard
                        bottomInsightsRow
                    }

                    VStack(spacing: 18) {
                        performanceCard
                        agendaCard
                        liveSignalsCard
                    }
                    .frame(width: 360)
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }

    private var heroPanel: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                LuumSectionHeader(
                    eyebrow: "Luum Command Center",
                    title: "Seu dia em contexto",
                    subtitle: "O luum cruza app em foco, URLs, categorias personalizadas, bloqueios e agenda para transformar monitoramento bruto em leitura util."
                )

                HStack(spacing: 10) {
                    StatusPill(
                        title: store.isMonitoring ? "Captura ativa" : "Captura pausada",
                        detail: store.currentActivityTitle,
                        tint: store.currentActivityCategory?.tint ?? ActivityCategory.utilities.tint
                    )

                    StatusPill(
                        title: agenda.isConnected ? "Agenda conectada" : "Agenda desconectada",
                        detail: agenda.profile?.email ?? "Google Calendar",
                        tint: agenda.isConnected ? LuumTheme.accent : LuumTheme.secondaryAccent
                    )

                    StatusPill(
                        title: LuumFormatters.dayLabel(selectedDay),
                        detail: "Dia selecionado",
                        tint: LuumTheme.electricBlue
                    )
                }
            }

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                FloatingSignalCard(
                    eyebrow: "Agora",
                    title: store.currentActivityTitle,
                    detail: store.currentActivityCategory?.title ?? "Aguardando atividade",
                    tint: store.currentActivityCategory?.glassTint ?? LuumTheme.accent.opacity(0.35)
                )

                FloatingSignalCard(
                    eyebrow: "Proxima agenda",
                    title: agenda.nextEvent?.title ?? "Sem evento na fila",
                    detail: nextAgendaLabel,
                    tint: LuumTheme.secondaryAccent.opacity(0.34)
                )
            }
            .frame(width: 320)
        }
        .padding(28)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.16), cornerRadius: 36)
    }

    private var timelineBoard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Timeline limpa")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Sem blocos sobrepostos. Cada acao fica listada com hora exata, contexto e categoria para voce entender o que realmente aconteceu.")
                        .foregroundStyle(LuumTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    LegendChip(title: "Atividade real", tint: LuumTheme.accent)
                    LegendChip(title: "Google Agenda", tint: LuumTheme.electricBlue)
                }
            }

            TimelineScene(activities: summary.timelineActivities, agendaItems: agenda.events)
                .frame(height: 720)
        }
        .padding(24)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12), cornerRadius: 34)
    }

    private var bottomInsightsRow: some View {
        HStack(alignment: .top, spacing: 22) {
            recentSessionsCard
            topBreakdownsCard
        }
    }

    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Mix de tempo")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if summary.categoryBreakdown.isEmpty {
                Text("Sem dados suficientes para o grafico por enquanto.")
                    .foregroundStyle(LuumTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Chart(summary.categoryBreakdown) { bucket in
                    SectorMark(
                        angle: .value("Tempo", bucket.duration),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(bucket.category.tint.gradient)
                }
                .frame(height: 210)

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
                                .font(.headline)
                        }
                    }
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12))
    }

    private var agendaCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Agenda")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                if let lastSyncAt = agenda.lastSyncAt {
                    Text("Sync \(LuumFormatters.relativeTime(until: lastSyncAt))")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textMuted)
                }
            }

            if !agenda.isConfigured {
                Text("Cole um Client ID do tipo Desktop app nas preferencias para conectar sua agenda.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else if !agenda.isConnected {
                Text("A configuracao esta pronta. Clique em conectar para puxar seus compromissos do Google Calendar.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else if agenda.events.isEmpty {
                Text("Nenhum compromisso encontrado para o dia selecionado.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                if let nextEvent = agenda.nextEvent {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Proximo bloco")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))

                        Text(nextEvent.title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(nextEvent.isAllDay ? "Dia inteiro" : LuumFormatters.timeRange(start: nextEvent.startDate, end: nextEvent.endDate))
                            .foregroundStyle(LuumTheme.electricBlue)
                    }
                    .padding(16)
                    .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.18), cornerRadius: 26, shadowOpacity: 0.18)
                }

                VStack(spacing: 10) {
                    ForEach(agenda.events.prefix(5)) { event in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LuumTheme.electricBlue.gradient)
                                .frame(width: 5, height: 42)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .foregroundStyle(.white)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)

                                Text(event.isAllDay ? "Dia inteiro" : LuumFormatters.timeRange(start: event.startDate, end: event.endDate))
                                    .foregroundStyle(LuumTheme.textSecondary)
                                    .font(.caption)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white.opacity(0.03))
                        )
                    }
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12))
    }

    private var liveSignalsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sinais ao vivo")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            MetricLine(
                title: "Tempo capturado",
                value: LuumFormatters.duration(summary.totalTrackedTime),
                detail: "Historico local do dia"
            )

            MetricLine(
                title: "Tempo planejado",
                value: LuumFormatters.duration(agenda.plannedTime),
                detail: "Compromissos da agenda"
            )

            MetricLine(
                title: "Cobertura do dia",
                value: trackedVersusPlanned,
                detail: "Tempo real vs agenda"
            )

            if let leadingCategory {
                MetricLine(
                    title: "Categoria lider",
                    value: leadingCategory.category.title,
                    detail: LuumFormatters.duration(leadingCategory.duration)
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
        .luumGlassCard(tint: ActivityCategory.utilities.glassTint)
    }

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Blocos recentes")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if summary.recentActivities.isEmpty {
                Text("Assim que voce abrir alguns apps, o luum vai mostrar os ultimos blocos aqui.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(summary.recentActivities.prefix(8)) { activity in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: activity.category.systemImage)
                                .foregroundStyle(activity.category.tint)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.pageTitle ?? activity.applicationName)
                                    .foregroundStyle(.white)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)

                                Text(activity.webDomain ?? activity.applicationName)
                                    .foregroundStyle(LuumTheme.textSecondary)
                                    .font(.caption)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(LuumFormatters.duration(activity.duration))
                                .foregroundStyle(.white.opacity(0.92))
                                .font(.caption.weight(.semibold))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white.opacity(0.025))
                        )
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12))
    }

    private var topBreakdownsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Motores do dia")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            BreakdownHighlight(
                title: "Top app",
                item: summary.appBreakdown.first,
                emptyState: "Nenhum app consolidado ainda.",
                tint: ActivityCategory.work.tint
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
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12))
    }
}

struct BreakdownListView: View {
    let title: String
    let subtitle: String
    let emptyState: String
    let items: [UsageBreakdownItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LuumSectionHeader(eyebrow: "Detalhe", title: title, subtitle: subtitle)

                if items.isEmpty {
                    Text(emptyState)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14))
                } else {
                    VStack(spacing: 12) {
                        ForEach(items) { item in
                            HStack(spacing: 14) {
                                Image(systemName: item.systemImage)
                                    .foregroundStyle(item.category?.tint ?? LuumTheme.accent)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.label)
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    if let secondaryLabel = item.secondaryLabel {
                                        Text(secondaryLabel)
                                            .font(.subheadline)
                                            .foregroundStyle(LuumTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(LuumFormatters.duration(item.duration))
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    if let category = item.category {
                                        Text(category.title)
                                            .font(.caption)
                                            .foregroundStyle(category.tint)
                                    }
                                }
                            }
                            .padding(18)
                            .luumGlassCard(tint: item.category?.glassTint ?? LuumTheme.accent.opacity(0.16))
                        }
                    }
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct TimelineScene: View {
    let activities: [ResolvedActivitySample]
    let agendaItems: [CalendarAgendaItem]

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            TimelineColumnCard(title: "Atividade real", icon: "waveform.path.ecg.rectangle.fill", tint: LuumTheme.accent) {
                if activities.isEmpty {
                    TimelineEmptyState(text: "Nenhuma atividade capturada neste dia.")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(activitySections, id: \.title) { section in
                                TimelineSectionHeader(title: section.title)

                                ForEach(section.activities) { activity in
                                    ActivityTimelineRow(activity: activity)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }

            TimelineColumnCard(title: "Agenda", icon: "calendar.badge.clock", tint: LuumTheme.electricBlue) {
                if agendaItems.isEmpty {
                    TimelineEmptyState(text: "Nenhum compromisso do Google Calendar para este dia.")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(agendaSections, id: \.title) { section in
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
        Dictionary(grouping: activities) { activity in
            activity.startDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)))
        }
        .map { key, value in
            ActivityTimelineSection(title: "\(key):00", activities: value.sorted { $0.startDate < $1.startDate })
        }
        .sorted { $0.activities.first?.startDate ?? .distantPast < $1.activities.first?.startDate ?? .distantPast }
    }

    private var agendaSections: [AgendaTimelineSection] {
        Dictionary(grouping: agendaItems) { event in
            event.startDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)))
        }
        .map { key, value in
            AgendaTimelineSection(title: "\(key):00", events: value.sorted { $0.startDate < $1.startDate })
        }
        .sorted { $0.events.first?.startDate ?? .distantPast < $1.events.first?.startDate ?? .distantPast }
    }
}

private struct ActivityTimelineSection {
    let title: String
    let activities: [ResolvedActivitySample]
}

private struct AgendaTimelineSection {
    let title: String
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
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(tint.opacity(0.16))
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

private struct ActivityTimelineRow: View {
    let activity: ResolvedActivitySample

    var body: some View {
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
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(activity.category.tint.opacity(0.16))
        )
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
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LuumTheme.electricBlue.opacity(0.14))
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
                .fill(.white.opacity(0.03))
        )
    }
}

private struct FloatingSignalCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(detail)
                .font(.caption)
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .luumGlassCard(tint: tint, cornerRadius: 28, shadowOpacity: 0.2)
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
                .fill(tint.opacity(0.18))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.08))
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
                .fill(.white.opacity(0.04))
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
    }
}
