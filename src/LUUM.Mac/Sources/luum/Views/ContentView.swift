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
        case .overview:
            "Resumo"
        case .search:
            "Busca"
        case .agenda:
            "Agenda"
        case .clients:
            "Clientes"
        case .apps:
            "Apps"
        case .websites:
            "Sites"
        case .team:
            "Equipe"
        case .categories:
            "Categorias"
        case .focus:
            "Foco"
        case .reminders:
            "Lembretes"
        case .reports:
            "Relatorios"
        }
    }

    var requiredFeature: LuumFeature {
        switch self {
        case .overview:
            .coreTracking
        case .search:
            .search
        case .agenda:
            .agendaIntegrations
        case .clients:
            .reports
        case .apps, .websites, .categories:
            .classification
        case .team:
            .teamWorkspace
        case .focus:
            .focusModes
        case .reminders:
            .reminders
        case .reports:
            .reports
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            "rectangle.stack.fill"
        case .search:
            "magnifyingglass"
        case .agenda:
            "calendar.badge.clock"
        case .clients:
            "briefcase.fill"
        case .apps:
            "app.connected.to.app.below.fill"
        case .websites:
            "globe"
        case .team:
            "person.3.fill"
        case .categories:
            "square.grid.2x2.fill"
        case .focus:
            "target"
        case .reminders:
            "bell.badge.fill"
        case .reports:
            "chart.xyaxis.line"
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
                HStack(alignment: .top, spacing: 22) {
                    sidebar
                        .frame(width: 244, alignment: .topLeading)

                    detailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 14)
                .padding(.top, 42)
                .padding(.bottom, 14)
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
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
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
                openSearch: { selection = .search },
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
                subtitle: "Os dominios ficam organizados de forma compacta para voce classificar ou ignorar cada site sem bagunca.",
                emptyState: "Nenhum site rastreado neste dia. Abra um navegador suportado e permita Automacao.",
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

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SidebarHero(store: store, summary: summary, agenda: agenda)

                VStack(alignment: .leading, spacing: 6) {
                    SidebarGroupLabel("Visão geral")

                    ForEach(primarySections) { section in
                        Button {
                            withAnimation(.spring(duration: 0.32, bounce: 0.18)) {
                                selection = section
                            }
                        } label: {
                            SidebarButtonRow(section: section, isSelected: selection == section, isLocked: !store.canUse(section.requiredFeature))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    SidebarGroupLabel("Controles")

                    ForEach(controlSections) { section in
                        Button {
                            withAnimation(.spring(duration: 0.32, bounce: 0.18)) {
                                selection = section
                            }
                        } label: {
                            SidebarButtonRow(section: section, isSelected: selection == section, isLocked: !store.canUse(section.requiredFeature))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    openSettings()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape.fill")
                        Text("Abrir Preferencias")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .luumGlassCard(tint: LuumTheme.accent.opacity(0.14), cornerRadius: 20, shadowOpacity: 0.12)
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct LoginRequiredView: View {
    let store: ActivityStore

    var body: some View {
        VStack(spacing: 20) {
            LuumAppMark(size: 72)

            VStack(spacing: 8) {
                Text("Entre no Luum")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("Use a mesma conta Firebase do site para liberar seu plano, backup e integracoes neste Mac. O app salva a sessao em um cofre local cifrado para evitar prompts das Chaves do macOS em builds ad-hoc.")
                    .font(.body)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
            }

            HStack(spacing: 12) {
                Button("Entrar pelo site") {
                    store.openLoginPage()
                }
                .buttonStyle(.glassProminent)

                Button("Ja entrei, validar") {
                    store.refreshAccountStatus()
                }
                .buttonStyle(.borderedProminent)
            }

            if let message = store.authStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.16), cornerRadius: 34)
    }
}

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
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12), cornerRadius: 30)
    }
}

private struct SidebarHero: View {
    let store: ActivityStore
    let summary: DailySummary
    let agenda: AgendaSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                LuumAppMark(size: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Luum")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(
                        store.accountEmail.isEmpty
                            ? "Plano \(store.accountPlan.title)"
                            : store.accountPlan.title
                    )
                    .font(.caption2)
                    .foregroundStyle(LuumTheme.textMuted)
                    .lineLimit(1)
                }

                Spacer()

                TimelineView(.animation(minimumInterval: 0.02, paused: !store.isMonitoring)) { ctx in
                    let phase = fmod(ctx.date.timeIntervalSinceReferenceDate, 1.8) / 1.8
                    ZStack {
                        if store.isMonitoring {
                            Circle()
                                .fill(LuumTheme.cyanGreen.opacity((1.0 - phase) * 0.38))
                                .frame(width: 18, height: 18)
                                .scaleEffect(1.0 + phase * 1.5)
                        }
                        Circle()
                            .fill(store.isMonitoring ? LuumTheme.cyanGreen : LuumTheme.textMuted)
                            .frame(width: 8, height: 8)
                            .shadow(color: store.isMonitoring ? LuumTheme.cyanGreen.opacity(0.65) : .clear, radius: 4)
                    }
                    .frame(width: 20, height: 20)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(store.currentActivityTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.3), value: store.currentActivityTitle)

                HStack(spacing: 6) {
                    Circle()
                        .fill(store.currentActivityCategory?.tint ?? LuumTheme.electricBlue)
                        .frame(width: 6, height: 6)
                    Text(store.currentActivityCategory?.title ?? "Aguardando classificacao")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(store.currentActivityCategory?.tint ?? LuumTheme.electricBlue)
                }
                .animation(.easeInOut(duration: 0.3), value: store.currentActivityCategory?.title)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((store.currentActivityCategory?.tint ?? LuumTheme.accent).opacity(0.10))
            )

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

            if let currentFocusBlockMatch = store.currentFocusBlockMatch {
                Label(currentFocusBlockMatch.title, systemImage: "hand.raised.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LuumTheme.hotPink)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .fixedSize(horizontal: false, vertical: true)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.10), cornerRadius: 16, shadowOpacity: 0.08)
    }
}

private struct SidebarGroupLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(LuumTheme.textMuted)
            .tracking(0.8)
            .padding(.horizontal, 12)
            .padding(.top, 2)
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
                .frame(width: 18)
                .foregroundStyle(isSelected ? .white : (isHovered ? .white.opacity(0.85) : LuumTheme.textSecondary))

            Text(section.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : (isHovered ? .white.opacity(0.85) : LuumTheme.textSecondary))

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LuumTheme.textMuted)
            }
        }
        .frame(minHeight: 36)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isSelected
                        ? .white.opacity(0.085)
                        : (isHovered ? .white.opacity(0.04) : .clear)
                )
        )
        .overlay {
            HStack {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? LuumTheme.accent : .clear)
                    .frame(width: 3)
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

private struct SidebarMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LuumTheme.textMuted)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LuumTheme.panelFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.03))
        }
    }
}

private struct ToolbarIcon: View {
    let symbol: String
    var isAccent: Bool = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(isAccent ? 0.96 : 0.82))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(isAccent ? LuumTheme.accent.opacity(0.34) : LuumTheme.panelFillStrong)
            )
            .overlay {
                Circle()
                    .stroke(isAccent ? LuumTheme.accent.opacity(0.34) : LuumTheme.surfaceOutline)
            }
    }
}
