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
                    .frame(width: 350)
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
                    title: "Seu dia em camadas",
                    subtitle: "O luum cruza app em foco, URLs e agenda para montar uma leitura mais precisa do que foi trabalho, reuniao, estudo ou entretenimento."
                )

                HStack(spacing: 10) {
                    StatusPill(
                        title: store.isMonitoring ? "Captura ativa" : "Captura pausada",
                        detail: store.currentActivityTitle,
                        tint: store.isMonitoring ? ActivityCategory.work.tint : ActivityCategory.utilities.tint
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
                    detail: store.currentSnapshot?.pageTitle ?? store.currentSnapshot?.category.title ?? "Aguardando atividade",
                    tint: store.currentSnapshot?.category.glassTint ?? LuumTheme.accent.opacity(0.35)
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
                    Text("Timeline do dia")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Apps e compromissos ficam lado a lado para voce entender o que foi planejado e o que de fato aconteceu.")
                        .foregroundStyle(LuumTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    LegendChip(title: "Atividade real", tint: LuumTheme.accent)
                    LegendChip(title: "Google Agenda", tint: LuumTheme.electricBlue)
                }
            }

            if summary.timelineActivities.isEmpty && agenda.events.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ainda nao ha blocos para este dia.")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Abra apps, navegue normalmente e conecte sua agenda para o painel ganhar profundidade.")
                        .foregroundStyle(LuumTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 520, alignment: .leading)
                .padding(28)
                .luumGlassCard(tint: LuumTheme.accent.opacity(0.12))
            } else {
                TimelineScene(day: selectedDay, activities: summary.timelineActivities, agendaItems: agenda.events)
                    .frame(height: 720)
            }
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
                    ForEach(summary.categoryBreakdown.prefix(4)) { bucket in
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

            if let message = store.googleCalendarStatusMessage {
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
                    ForEach(summary.recentActivities.prefix(6)) { activity in
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

struct CategoryListView: View {
    let summary: DailySummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LuumSectionHeader(
                    eyebrow: "Categorias",
                    title: "Leitura contextual",
                    subtitle: "O luum cruza nome do app, bundle e dominio para transformar uso bruto em contexto."
                )

                if summary.categoryBreakdown.isEmpty {
                    Text("Ainda nao existem categorias consolidadas para este dia.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .padding(20)
                        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14))
                } else {
                    VStack(spacing: 12) {
                        ForEach(summary.categoryBreakdown) { bucket in
                            HStack {
                                Label(bucket.category.title, systemImage: bucket.category.systemImage)
                                    .foregroundStyle(.white)

                                Spacer()

                                Text(LuumFormatters.duration(bucket.duration))
                                    .foregroundStyle(bucket.category.tint)
                                    .font(.headline)
                            }
                            .padding(18)
                            .luumGlassCard(tint: bucket.category.glassTint)
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
    let day: Date
    let activities: [ActivitySample]
    let agendaItems: [CalendarAgendaItem]

    private let hours = Array(0 ... 23)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Apps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 66)

                Text("Agenda")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 160, alignment: .leading)
            }

            GeometryReader { proxy in
                let totalHeight = proxy.size.height
                let labelWidth: CGFloat = 56
                let columnSpacing: CGFloat = 18
                let columnWidth = max(140, (proxy.size.width - labelWidth - columnSpacing) / 2)
                let startOfDay = Calendar.autoupdatingCurrent.startOfDay(for: day)

                ZStack(alignment: .topLeading) {
                    ForEach(hours, id: \.self) { hour in
                        let yPosition = totalHeight * CGFloat(hour) / 24

                        Path { path in
                            path.move(to: CGPoint(x: labelWidth, y: yPosition))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: yPosition))
                        }
                        .stroke(.white.opacity(hour.isMultiple(of: 2) ? 0.09 : 0.04), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

                        Text(String(format: "%02d:00", hour))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: labelWidth - 10, alignment: .trailing)
                            .offset(x: 0, y: max(0, yPosition - 8))
                    }

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.white.opacity(0.03))
                        .frame(width: columnWidth, height: totalHeight)
                        .offset(x: labelWidth, y: 0)

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.white.opacity(0.02))
                        .frame(width: columnWidth, height: totalHeight)
                        .offset(x: labelWidth + columnWidth + columnSpacing, y: 0)

                    ForEach(activities) { activity in
                        TimelineActivityBlock(activity: activity)
                            .frame(width: columnWidth - 12, height: blockHeight(from: activity.startDate, to: activity.endDate, totalHeight: totalHeight))
                            .offset(
                                x: labelWidth + 6,
                                y: yOffset(for: activity.startDate, startOfDay: startOfDay, totalHeight: totalHeight)
                            )
                    }

                    ForEach(agendaItems) { event in
                        TimelineAgendaBlock(event: event)
                            .frame(width: columnWidth - 12, height: blockHeight(from: event.startDate, to: event.endDate, totalHeight: totalHeight))
                            .offset(
                                x: labelWidth + columnWidth + columnSpacing + 6,
                                y: yOffset(for: event.startDate, startOfDay: startOfDay, totalHeight: totalHeight)
                            )
                    }
                }
            }
        }
    }

    private func yOffset(for date: Date, startOfDay: Date, totalHeight: CGFloat) -> CGFloat {
        let elapsed = max(0, min(86_400, date.timeIntervalSince(startOfDay)))
        return CGFloat(elapsed / 86_400) * totalHeight
    }

    private func blockHeight(from start: Date, to end: Date, totalHeight: CGFloat) -> CGFloat {
        let duration = max(900, end.timeIntervalSince(start))
        return max(34, CGFloat(duration / 86_400) * totalHeight)
    }
}

private struct TimelineActivityBlock: View {
    let activity: ActivitySample

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(activity.pageTitle ?? activity.applicationName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(activity.webDomain ?? activity.applicationName)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(LuumFormatters.timeRange(start: activity.startDate, end: activity.endDate))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(activity.category.tint.opacity(0.88).gradient)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12))
        }
    }
}

private struct TimelineAgendaBlock: View {
    let event: CalendarAgendaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            if let location = event.location {
                Text(location)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(event.isAllDay ? "Dia inteiro" : LuumFormatters.timeRange(start: event.startDate, end: event.endDate))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [LuumTheme.electricBlue.opacity(0.95), LuumTheme.accent.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12))
        }
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
