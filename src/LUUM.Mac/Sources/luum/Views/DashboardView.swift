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
    let openSearch: (_ query: String) -> Void
    let openSettings: () -> Void

    @State private var aiQuery = ""
    @State private var appeared = false

    private var leadingCategory: CategoryBreakdown? {
        summary.categoryBreakdown.first
    }

    private var categoryTotal: TimeInterval {
        summary.categoryBreakdown.reduce(0) { $0 + $1.duration }
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
        case 5 ..< 12: return "Bom dia"
        case 12 ..< 18: return "Boa tarde"
        default: return "Boa noite"
        }
    }

    // "Boa noite, " branco + "Luum" em #5a5a62
    private var greetingAttributed: AttributedString {
        let greeting = AttributedString("\(greetingTitle), ")
        var luum = AttributedString("Luum")
        luum[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Color(red: 0.353, green: 0.353, blue: 0.384)
        return greeting + luum
    }

    private var heroSubtitleText: String {
        if let categoryTitle = store.currentActivityCategory?.title {
            return categoryTitle
        }
        return store.isMonitoring ? "Aguardando classificação · captura local ligada" : "Monitoramento pausado"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Cabecalho: saudacao + navegacao de data (SEM card wrapper)
                pageHeader
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -12)
                    .animation(.spring(duration: 0.5, bounce: 0.2), value: appeared)

                // Card hero: atividade atual + proxima agenda
                heroCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(duration: 0.55, bounce: 0.18).delay(0.06), value: appeared)

                // Barra de IA
                aiPromptField
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(duration: 0.4, bounce: 0.15).delay(0.10), value: appeared)

                aiResponseCard
                    .animation(.spring(duration: 0.35, bounce: 0.15), value: store.isQueryingAI)
                    .animation(.spring(duration: 0.35, bounce: 0.15), value: store.aiQueryResponse != nil)
                    .animation(.spring(duration: 0.35, bounce: 0.15), value: store.aiQueryError != nil)

                // 3 cartoes de metricas
                metricsStrip
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(.spring(duration: 0.55, bounce: 0.18).delay(0.14), value: appeared)

                if store.needsOnboarding {
                    onboardingCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(duration: 0.5, bounce: 0.15).delay(0.18), value: appeared)
                }

                // Grade 2 colunas: categorias (380pt) + agenda com chips embutidos
                HStack(alignment: .top, spacing: 16) {
                    performanceCard
                        .frame(width: 380)
                    agendaCard
                        .frame(maxWidth: .infinity)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(duration: 0.6, bounce: 0.15).delay(0.20), value: appeared)
            }
            .padding(.horizontal, 44)
            .padding(.top, 34)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .task {
            appeared = true
        }
    }

    // MARK: - onboardingCard

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Onboarding rápido")
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

    // MARK: - pageHeader

    // SEM card wrapper — apenas layout HStack com eyebrow + titulo 33px + date nav
    private var pageHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                // Eyebrow: 11px weight:600 tracking:.09em color:#6e6e76
                Text("VISÃO GERAL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                    .tracking(0.99) // ~.09em at 11px

                // Titulo: 33px weight:680 tracking:-.02em — "Luum" em #5a5a62 via AttributedString
                Text(greetingAttributed)
                    .font(.system(size: 33, weight: .bold))
                    .foregroundStyle(Color(red: 0.961, green: 0.961, blue: 0.969)) // #f5f5f7 para a parte sem cor explícita
                    .tracking(-0.66)
                    .animation(.easeInOut(duration: 0.4), value: greetingTitle)

                // Subtitulo: 15px color:#9a9aa2
                Text("Aqui está o que importa agora.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 0.604, green: 0.604, blue: 0.635)) // #9a9aa2
            }

            Spacer(minLength: 20)

            // Date nav: chevron-left + pill com data + chip "Hoje" accent + chevron-right
            DashboardDatePanel(selectedDay: $selectedDay)
        }
    }

    // MARK: - heroCard

    private var heroCard: some View {
        HStack(alignment: .top, spacing: 0) {
            // Atividade atual
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    LuumPulsingDot(isActive: store.isMonitoring, color: LuumTheme.accent, size: 7)
                    Text("Agora".uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                        .tracking(0.72) // .06em
                }

                Text(store.isMonitoring ? store.currentActivityTitle : "Nenhuma atividade ativa")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .tracking(-0.3)
                    .lineLimit(2)
                    .padding(.top, 10)
                    .animation(.easeInOut(duration: 0.3), value: store.currentActivityTitle)

                Text(heroSubtitleText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                    .padding(.top, 4)

                HStack(spacing: 10) {
                    // Iniciar foco: background accent + shadow
                    Button {
                        openFocus()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Iniciar foco")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(LuumTheme.accent)
                                .shadow(color: LuumTheme.accent.opacity(0.45), radius: 12, x: 0, y: 6)
                        )
                    }
                    .buttonStyle(.plain)

                    // Conectar agenda: rgba(255,255,255,.07)
                    Button {
                        openAgenda()
                    } label: {
                        Text("Conectar agenda")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(26)
            // Decoracao radial absoluta: posicionada no topTrailing, FORA do padding como overlay
            .overlay(alignment: .topTrailing) {
                RadialGradient(
                    colors: [LuumTheme.accent.opacity(0.22), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 120
                )
                .frame(width: 240, height: 240)
                .offset(x: 40, y: -60)
                .allowsHitTesting(false)
            }
            .clipped()

            // Divisor vertical: 1px rgba(255,255,255,.08)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            // Próxima agenda: width:300
            VStack(alignment: .leading, spacing: 10) {
                Text("Próxima agenda".uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                    .tracking(0.72)

                if let nextEvent = agenda.nextEvent {
                    Text(nextEvent.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(.top, 4)

                    Text(nextEvent.isAllDay ? "Dia inteiro" : LuumFormatters.timeRange(start: nextEvent.startDate, end: nextEvent.endDate))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LuumTheme.electricBlue)

                    Text("\(nextEvent.accountLabel) · \(nextEvent.calendarTitle)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463))
                        .padding(.top, 2)
                } else {
                    Text("Sem compromisso em fila")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 4)

                    Text(agenda.isConnected
                        ? "Nenhum evento nas próximas horas."
                        : "Conecte Google, Notion ou Outlook para o Luum comparar o plano com o uso real.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
            .frame(width: 300, alignment: .topLeading)
            .padding(26)
        }
        // overflow:hidden via clipped no container
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - aiPromptField

    // height:58px, fundo accent.opacity(0.07), border accent.opacity(0.22), sparkle accentLight, badge "Em breve"
    private var aiPromptField: some View {
        HStack(spacing: 12) {
            if store.isQueryingAI {
                ProgressView()
                    .scaleEffect(0.65)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(red: 0.725, green: 0.651, blue: 1.0))
            }

            TextField(
                "Pergunte ao Luum... \"O que fiz hoje?\" ou \"Qual projeto está em risco?\"",
                text: $aiQuery
            )
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .textFieldStyle(.plain)
            .disabled(store.isQueryingAI)
            .onSubmit {
                if !aiQuery.isEmpty {
                    store.sendAIQuery(aiQuery)
                    aiQuery = ""
                }
            }

            if !aiQuery.isEmpty && !store.isQueryingAI {
                Button {
                    store.sendAIQuery(aiQuery)
                    aiQuery = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LuumTheme.accent)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else if aiQuery.isEmpty && !store.isQueryingAI {
                // Badge "Em breve": background rgba(255,255,255,.06), radius 7, padding 4 10, 12px weight:600 #9a9aa2
                Text("Em breve")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.604, green: 0.604, blue: 0.635)) // #9a9aa2
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }
        }
        .animation(.spring(duration: 0.22, bounce: 0.25), value: aiQuery.isEmpty || store.isQueryingAI)
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LuumTheme.accent.opacity(0.07))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    store.isQueryingAI
                        ? LuumTheme.accent.opacity(0.50)
                        : LuumTheme.accent.opacity(0.22),
                    lineWidth: 1
                )
                .animation(.easeInOut(duration: 0.25), value: store.isQueryingAI)
        }
    }

    // MARK: - aiResponseCard

    @ViewBuilder
    private var aiResponseCard: some View {
        if store.isQueryingAI {
            HStack(spacing: 10) {
                ProgressView().scaleEffect(0.7)
                Text("Consultando Luum...")
                    .font(.subheadline)
                    .foregroundStyle(LuumTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .luumGlassCard(tint: LuumTheme.accent.opacity(0.08), cornerRadius: 28, shadowOpacity: 0.08)
            .transition(.opacity.combined(with: .offset(y: -6)))
        } else if let response = store.aiQueryResponse {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LuumTheme.accent)
                    Text(response.query)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LuumTheme.textMuted)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            store.clearAIQuery()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(LuumTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                }

                Text(response.answer)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .luumGlassCard(tint: LuumTheme.accent.opacity(0.12), cornerRadius: 28, shadowOpacity: 0.10)
            .transition(.opacity.combined(with: .offset(y: -6)))
        } else if let error = store.aiQueryError {
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(LuumTheme.textMuted)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(LuumTheme.textMuted)
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        store.clearAIQuery()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(LuumTheme.textMuted)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .luumGlassCard(tint: .clear, cornerRadius: 28, shadowOpacity: 0.04)
            .transition(.opacity.combined(with: .offset(y: -6)))
        }
    }

    // MARK: - metricsStrip

    // 3 cards em grid 1fr 1fr 1fr, gap:16, label 12px uppercase, valor 30px bold, detalhe 13px accentLight com →
    private var metricsStrip: some View {
        HStack(spacing: 16) {
            OverviewMetricCard(
                title: "Tempo capturado",
                value: LuumFormatters.duration(summary.totalTrackedTime),
                detail: "histórico do dia →",
                tint: LuumTheme.accent,
                action: openReports
            )

            OverviewMetricCard(
                title: "Cobertura",
                value: trackedVersusPlanned,
                detail: "real vs agenda →",
                tint: LuumTheme.electricBlue,
                action: openAgenda
            )

            OverviewMetricCard(
                title: "Categoria lider",
                value: leadingCategory?.category.title ?? "Sem dados",
                detail: leadingCategory.map { LuumFormatters.duration($0.duration) + " capturados" } ?? "aguardando uso",
                tint: leadingCategory?.category.tint ?? LuumTheme.textMuted,
                action: openCategories
            )
        }
    }

    // MARK: - agendaCard

    // Card de agenda com chips de acao fixados ao fundo — identico ao design HTML
    private var agendaCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Agenda")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let lastSyncAt = agenda.lastSyncAt {
                    Text("sync \(LuumFormatters.relativeTime(until: lastSyncAt))")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textMuted)
                }
                Button("Ver agenda") {
                    openAgenda()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.725, green: 0.651, blue: 1.0))
            }

            // Conteudo da agenda
            Group {
                if !agenda.isConfigured {
                    Text("Adicione Google e/ou Notion nas preferências para liberar a comparação com a agenda.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                } else if !agenda.isConnected {
                    Text("A configuração está pronta. Falta sincronizar pelo menos uma fonte para puxar os compromissos.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                } else if agenda.events.isEmpty {
                    Text("Nenhum compromisso encontrado entre a data escolhida e os próximos 3 dias.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if !agenda.hasEventsInFocusDay {
                            Text("Sem eventos no dia selecionado. Mostrando apenas os próximos compromissos dentro de 3 dias.")
                                .foregroundStyle(LuumTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let nextEvent = agenda.nextEvent {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Próximo bloco")
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
                    .padding(.top, 10)
                }
            }

            Spacer(minLength: 18)

            // Chips de acao — fixados ao fundo do card como no design HTML
            HStack(spacing: 10) {
                HomeActionChip(
                    title: "Relatório semanal",
                    detail: "tendências e export",
                    tint: LuumTheme.accent,
                    symbol: "chart.xyaxis.line",
                    action: openReports
                )
                HomeActionChip(
                    title: "Equipe e ranking",
                    detail: "ao vivo",
                    tint: Color(red: 0.208, green: 0.902, blue: 0.639), // #35e6a3
                    symbol: "person.2.fill",
                    action: openTeam
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    // MARK: - performanceCard

    // Donut 118x118 lado a lado com legenda (percentuais) — identico ao design HTML
    private var performanceCard: some View {
        Button(action: openCategories) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Categorias")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Editar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.725, green: 0.651, blue: 1.0)) // #b9a6ff
                }

                if summary.categoryBreakdown.isEmpty {
                    Text("Sem dados suficientes para mostrar o mix do dia.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .center, spacing: 22) {
                        // Donut com texto central: "4h 7m" + "capturado"
                        ZStack {
                            Chart(summary.categoryBreakdown) { bucket in
                                SectorMark(
                                    angle: .value("Tempo", bucket.duration),
                                    innerRadius: .ratio(0.64),
                                    angularInset: 2
                                )
                                .foregroundStyle(bucket.category.tint.gradient)
                            }
                            .frame(width: 118, height: 118)

                            VStack(spacing: 2) {
                                Text(LuumFormatters.duration(summary.totalTrackedTime))
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("capturado")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                            }
                        }
                        .frame(width: 118, height: 118)

                        // Legenda: square 9px + nome #cfcfd4 + percentual #6e6e76
                        VStack(spacing: 9) {
                            ForEach(summary.categoryBreakdown.prefix(5)) { bucket in
                                HStack(spacing: 9) {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(bucket.category.tint)
                                        .frame(width: 9, height: 9)
                                    Text(bucket.category.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color(red: 0.812, green: 0.812, blue: 0.831)) // #cfcfd4
                                    Spacer()
                                    if categoryTotal > 0 {
                                        Text("\(Int(round(bucket.duration / categoryTotal * 100)))%")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                                            .monospacedDigit()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    // MARK: - handleOnboarding

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

// MARK: - TimelineScene

private struct TimelineScene: View {
    let store: ActivityStore
    let activities: [ResolvedActivitySample]
    let agendaItems: [CalendarAgendaItem]
    var openApps: (() -> Void)? = nil
    var openAgenda: (() -> Void)? = nil

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
                    TimelineEmptyState(
                        text: "Nenhuma atividade capturada neste dia. Certifique-se de que o monitoramento está ativo.",
                        actionTitle: openApps != nil ? "Ver apps e sites" : nil,
                        action: openApps
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
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
                    TimelineEmptyState(
                        text: "Nenhum compromisso das fontes integradas para o dia selecionado ou para os próximos 3 dias.",
                        actionTitle: openAgenda != nil ? "Conectar agenda" : nil,
                        action: openAgenda
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
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
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text)
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption.weight(.semibold))
                        Text(actionTitle)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(LuumTheme.electricBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(LuumTheme.electricBlue.opacity(0.12))
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(LuumTheme.electricBlue.opacity(0.28), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
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

// MARK: - OverviewMetricCard
// label 12px uppercase tracking:.05em color:#6e6e76
// valor 30px weight:680 tracking:-.02em (tabular-nums)
// detalhe 13px color:accentLight cursor:pointer com →

private struct OverviewMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Label: 12px weight:600 tracking:.05em uppercase color:#6e6e76
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                    .tracking(0.6) // ~.05em at 12px

                // Valor: 30px weight bold (tabular-nums) tracking:-.02em
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .tracking(-0.6) // -.02em at 30px
                    .padding(.top, 8)

                // Detalhe: 13px accentLight (tint do card) com →
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(.spring(duration: 0.2, bounce: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }
}

// MARK: - DashboardDatePanel
// chevron-left + pill com data (background rgba(255,255,255,.05) border .08 radius 10 padding 7 14 14px weight:600)
// + chip "Hoje" (background rgba(124,92,255,.18) border rgba(124,92,255,.3) color accentLight)
// + chevron-right

private struct DashboardDatePanel: View {
    @Binding var selectedDay: Date

    private var isToday: Bool {
        Calendar.autoupdatingCurrent.isDateInToday(selectedDay)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Chevron esquerdo
            Button {
                shiftDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Pill com data: background rgba(255,255,255,.05), border .08, radius 10, padding 7 14
            HStack(spacing: 8) {
                DatePicker("Dia", selection: $selectedDay, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 122)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }

            // Chip "Hoje": accent bg quando selecionado, cinza quando nao
            Button("Hoje") {
                selectedDay = Date()
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isToday ? Color(red: 0.725, green: 0.651, blue: 1.0) : Color.white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isToday ? LuumTheme.accent.opacity(0.18) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isToday ? LuumTheme.accent.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 1)
            }

            // Chevron direito
            Button {
                shiftDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func shiftDay(by value: Int) {
        selectedDay = Calendar.autoupdatingCurrent.date(byAdding: .day, value: value, to: selectedDay) ?? selectedDay
    }
}

// MARK: - HomeActionChip
// icone 30x30 rounded-8 + titulo 13px weight:600 + detalhe 12px #6e6e76

private struct HomeActionChip: View {
    let title: String
    let detail: String
    let tint: Color
    let symbol: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                }

                Spacer()
            }
            .padding(11)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.06 : 0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
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
