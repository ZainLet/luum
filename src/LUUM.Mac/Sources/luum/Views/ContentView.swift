import SwiftUI

private enum LUUMSection: String, CaseIterable, Identifiable {
    case overview
    case search
    case agenda
    case clients
    case apps
    case websites
    case team
    case categories
    case focus
    case reminders
    case reports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:   "Resumo"
        case .search:     "Busca"
        case .agenda:     "Agenda"
        case .clients:    "Clientes"
        case .apps:       "Apps"
        case .websites:   "Sites"
        case .team:       "Equipe"
        case .categories: "Categorias"
        case .focus:      "Foco"
        case .reminders:  "Lembretes"
        case .reports:    "Relatórios"
        }
    }

    var requiredFeature: LuumFeature {
        switch self {
        case .overview:               .coreTracking
        case .search:                 .search
        case .agenda:                 .agendaIntegrations
        case .clients:                .reports
        case .apps, .websites, .categories: .classification
        case .team:                   .teamWorkspace
        case .focus:                  .focusModes
        case .reminders:              .reminders
        case .reports:                .reports
        }
    }

    var systemImage: String {
        switch self {
        case .overview:   "rectangle.grid.2x2"           // grid dashboard como no HTML
        case .search:     "magnifyingglass"
        case .agenda:     "calendar"
        case .clients:    "briefcase"
        case .apps:       "square.grid.2x2"              // 4 squares como no HTML
        case .websites:   "globe"
        case .team:       "person.2"
        case .categories: "tag"                           // tag/label como no HTML (diamond)
        case .focus:      "scope"                         // concentric circles como no HTML
        case .reminders:  "bell"
        case .reports:    "chart.line.uptrend.xyaxis"    // line chart como no HTML
        }
    }
}

struct ContentView: View {
    let store: ActivityStore

    @Environment(\.openSettings) private var openSettings
    @State private var selection: LUUMSection = .overview
    @State private var selectedDay = Date()

    private var summary: DailySummary {
        _ = store.summaryRevision
        return store.summary(for: selectedDay)
    }

    private var todaySummary: DailySummary {
        _ = store.summaryRevision
        return store.summary(for: Date())
    }

    private var agenda: AgendaSummary {
        store.agendaSummary(for: selectedDay)
    }

    private var selectedDayAnchor: Date {
        Calendar.autoupdatingCurrent.startOfDay(for: selectedDay)
    }

    private var primarySections: [LUUMSection] {
        [.overview, .search, .agenda, .clients, .apps, .websites, .team]
    }

    private var controlSections: [LUUMSection] {
        [.categories, .focus, .reminders, .reports]
    }

    var body: some View {
        ZStack {
            LuumBackdrop()

            if store.isSignedIn {
                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 280)

                    // Divisor lateral: 1px solid rgba(255,255,255,.06)
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)

                    detailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                LoginRequiredView(store: store)
                    .padding(40)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.isSignedIn {
                LuumStatusBar(store: store, summary: todaySummary)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Luum")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .tracking(0.3)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if store.isGoogleCalendarConnected || store.notionCalendarSettings.isEnabled || store.outlookCalendarSettings.isEnabled || store.clickUpSettings.isEnabled || store.linearSettings.isEnabled {
                    Button {
                        store.refreshIntegratedCalendars(for: selectedDay)
                    } label: {
                        ToolbarIcon(symbol: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.plain)
                    .help("Sincronizar fontes de agenda")
                } else {
                    Button {
                        selection = .agenda
                    } label: {
                        ToolbarIcon(symbol: "calendar.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .help("Conectar agenda")
                }

                Button {
                    store.toggleMonitoring()
                } label: {
                    ToolbarIcon(symbol: store.isMonitoring ? "pause.fill" : "play.fill", isAccent: true)
                }
                .buttonStyle(.plain)
                .help(store.isMonitoring ? "Pausar monitoramento" : "Iniciar monitoramento")

                if store.isSignedIn {
                    Button {
                        store.refreshAccountStatus()
                    } label: {
                        ToolbarIcon(symbol: store.isCheckingAuth ? "arrow.triangle.2.circlepath" : "person.crop.circle.badge.checkmark")
                    }
                    .buttonStyle(.plain)
                    .help("Validar assinatura")
                }

                Button {
                    openSettings()
                } label: {
                    ToolbarIcon(symbol: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                .help("Preferencias")
            }
        }
        .task(id: selectedDayAnchor) {
            await store.ensureAgenda(for: selectedDay)
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        if !store.canUse(selection.requiredFeature) {
            LockedFeatureView(
                title: selection.title,
                feature: selection.requiredFeature,
                message: store.lockMessage(for: selection.requiredFeature),
                accountEmail: store.accountEmail,
                accountPlan: store.accountPlan,
                openPlans: { store.openLoginPage() },
                refresh: { store.refreshAccountStatus() }
            )
        } else {
            switch selection {
            case .overview:
                DashboardView(
                    store: store,
                    selectedDay: $selectedDay,
                    summary: summary,
                    agenda: agenda,
                    openAgenda: { selection = .agenda },
                    openApps: { selection = .apps },
                    openWebsites: { selection = .websites },
                    openTeam: { selection = .team },
                    openCategories: { selection = .categories },
                    openFocus: { selection = .focus },
                    openReports: { selection = .reports },
                    openSearch: { _ in selection = .search },
                    openSettings: { openSettings() }
                )
            case .search:
                SearchView(store: store) { result in
                    selectedDay = result.date
                    selection = result.kind == .agenda ? .agenda : .overview
                }
            case .agenda:
                AgendaView(store: store, selectedDay: selectedDay, agenda: agenda)
            case .clients:
                BusinessWorkspaceView(store: store)
            case .apps:
                QuickClassificationView(
                    store: store,
                    kind: .applications,
                    title: "Tempo por aplicativo",
                    subtitle: "Revise os apps do dia com busca, troca de categoria e bloqueio rapido, sem depender de uma lista enorme de regras.",
                    emptyState: "Nenhum aplicativo rastreado neste dia.",
                    selectedDay: selectedDay
                )
            case .websites:
                QuickClassificationView(
                    store: store,
                    kind: .websites,
                    title: "Tempo por site",
                    subtitle: "Os domínios ficam organizados de forma compacta para você classificar ou ignorar cada site sem bagunça.",
                    emptyState: "Nenhum site rastreado neste dia. Abra um navegador suportado e permita Automação.",
                    selectedDay: selectedDay
                )
            case .team:
                TeamRankingView(store: store, selectedDay: selectedDay)
            case .categories:
                CategoryCustomizationView(store: store, selectedDay: selectedDay)
            case .focus:
                FocusModesView(store: store, selectedDay: selectedDay)
            case .reminders:
                RemindersView(store: store)
            case .reports:
                ReportsView(store: store, selectedDay: selectedDay)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Brand + status card
                    SidebarHero(store: store, summary: summary, agenda: agenda)
                        .padding(.horizontal, 14)
                        .padding(.top, 16)
                        .padding(.bottom, 6)

                    // VISAO GERAL
                    SidebarGroupLabel("Visão geral")
                    ForEach(primarySections) { section in
                        Button {
                            withAnimation(.spring(duration: 0.28, bounce: 0.14)) {
                                selection = section
                            }
                        } label: {
                            SidebarButtonRow(section: section, isSelected: selection == section, isLocked: !store.canUse(section.requiredFeature))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                    }

                    // CONTROLES
                    SidebarGroupLabel("Controles")
                    ForEach(controlSections) { section in
                        Button {
                            withAnimation(.spring(duration: 0.28, bounce: 0.14)) {
                                selection = section
                            }
                        } label: {
                            SidebarButtonRow(section: section, isSelected: selection == section, isLocked: !store.canUse(section.requiredFeature))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                    }

                    Spacer(minLength: 16)
                }
            }
            .scrollIndicators(.hidden)

            // Preferencias — fixado ao fundo
            Divider()
                .overlay(Color.white.opacity(0.06))

            // Settings button: border rgba(255,255,255,.07) sem fill
            Button {
                openSettings()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .light))
                        .frame(width: 19)
                        .foregroundStyle(LuumTheme.textSecondary)
                    Text("Abrir Preferências")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LuumTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .background(.ultraThinMaterial)
        .background(LuumTheme.sidebarBlack.opacity(0.88))
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Login Required

private struct LoginRequiredView: View {
    let store: ActivityStore

    var body: some View {
        VStack(spacing: 20) {
            LuumAppMark(size: 72)

            VStack(spacing: 8) {
                Text("Entre no Luum")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("Use a mesma conta Firebase do site para liberar seu plano, backup e integrações neste Mac.")
                    .font(.body)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            HStack(spacing: 12) {
                Button("Entrar pelo site") { store.openLoginPage() }
                    .buttonStyle(.glassProminent)

                Button("Ja entrei, validar") { store.refreshAccountStatus() }
                    .buttonStyle(.borderedProminent)
            }

            if let message = store.authStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.14), cornerRadius: 28)
    }
}

// MARK: - Locked Feature

private struct LockedFeatureView: View {
    let title: String
    let feature: LuumFeature
    let message: String
    let accountEmail: String
    let accountPlan: LuumAccountPlan
    let openPlans: () -> Void
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: "lock.fill")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)

            Text(message)
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !accountEmail.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conta atual")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LuumTheme.textMuted)
                        .textCase(.uppercase)

                    Text("\(accountEmail) • Plano \(accountPlan.title)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                Button("Ver planos / entrar") { openPlans() }
                    .buttonStyle(.glassProminent)

                Button("Revalidar plano") { refresh() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
        .padding(28)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12), cornerRadius: 20)
    }
}

// MARK: - Sidebar Hero (status card)

private struct SidebarHero: View {
    let store: ActivityStore
    let summary: DailySummary
    let agenda: AgendaSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Brand row: logo L + nome/plano + pulsing dot
            HStack(alignment: .center, spacing: 11) {
                // Logo real do Luum 34x34 com sombra accent
                LuumAppMark(size: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: LuumTheme.accent.opacity(0.5), radius: 7, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Luum")
                        .font(.system(size: 15, weight: .semibold))  // weight:650
                        .foregroundStyle(.white)

                    // "Equipes" — plano atual
                    Text(
                        store.accountEmail.isEmpty
                            ? "Plano \(store.accountPlan.title)"
                            : store.accountPlan.title
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                    .lineLimit(1)
                }

                Spacer()

                // Pulsing dot ciano 9x9
                LuumPulsingDot(isActive: store.isMonitoring, color: LuumTheme.electricBlue, size: 9)
            }

            // Status card: background rgba(255,255,255,.04), border .07, radius 13, padding 13 14
            VStack(alignment: .leading, spacing: 7) {
                // Titulo da atividade atual
                Text(store.isMonitoring ? store.currentActivityTitle : "Nenhuma atividade ativa agora")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.25), value: store.currentActivityTitle)

                // Dot + categoria
                HStack(spacing: 7) {
                    Circle()
                        .fill(store.currentActivityCategory?.tint ?? Color(red: 0.725, green: 0.651, blue: 1.0))
                        .frame(width: 7, height: 7)
                    Text(store.currentActivityCategory?.title ?? "Aguardando classificação")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(store.currentActivityCategory?.tint ?? Color(red: 0.725, green: 0.651, blue: 1.0))
                }
                .animation(.easeInOut(duration: 0.2), value: store.currentActivityCategory?.title)

                // 3 metric pills: HOJE / AGENDA / FOCO
                HStack(spacing: 8) {
                    SidebarMetricPill(title: "Hoje", value: LuumFormatters.duration(summary.totalTrackedTime))
                    SidebarMetricPill(title: "Agenda", value: LuumFormatters.duration(agenda.plannedTime))
                    SidebarMetricPill(
                        title: "Foco",
                        value: store.currentFocusBlockMatch == nil
                            ? (store.focusShieldProfilesCount == 0 ? "Livre" : "\(store.focusShieldProfilesCount)")
                            : "Ativo"
                    )
                }

                if let block = store.currentFocusBlockMatch {
                    Label(block.title, systemImage: "hand.raised.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LuumTheme.hotPink)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sidebar Nav Components

private struct SidebarGroupLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            // color:#5a5a62
            .foregroundStyle(Color(red: 0.353, green: 0.353, blue: 0.384))
            .tracking(0.77) // ~.07em at 11px
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }
}

private struct SidebarButtonRow: View {
    let section: LUUMSection
    let isSelected: Bool
    var isLocked = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.systemImage)
                .font(.system(size: 17, weight: .light))
                .frame(width: 19)
                .foregroundStyle(
                    isSelected
                        ? Color(red: 0.725, green: 0.651, blue: 1.0)
                        : (isHovered ? Color.white.opacity(0.9) : Color(red: 0.604, green: 0.604, blue: 0.635)) // #9a9aa2
                )

            Text(section.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    isSelected
                        ? Color(red: 0.725, green: 0.651, blue: 1.0)          // color:#b9a6ff
                        : (isHovered ? Color(red: 0.961, green: 0.961, blue: 0.969) : Color(red: 0.604, green: 0.604, blue: 0.635)) // #f5f5f7 / #9a9aa2
                )

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LuumTheme.textMuted)
            }
        }
        .frame(minHeight: 36)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isSelected
                        ? LuumTheme.accent.opacity(0.16)    // rgba(124,92,255,.16)
                        : (isHovered ? Color.white.opacity(0.06) : .clear) // rgba(255,255,255,.06)
                )
        )
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .animation(.easeInOut(duration: 0.14), value: isSelected)
        .onHover { isHovered = $0 }
    }
}

private struct SidebarMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.463)) // #6e6e76
                .tracking(0.7)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Toolbar Icon

private struct ToolbarIcon: View {
    let symbol: String
    var isAccent: Bool = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(isAccent ? 0.96 : 0.80))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isAccent ? LuumTheme.accent.opacity(0.30) : Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isAccent ? LuumTheme.accent.opacity(0.40) : Color.white.opacity(0.07), lineWidth: 1)
            }
    }
}
