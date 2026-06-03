import SwiftUI

private enum LUUMSection: String, CaseIterable, Identifiable {
    case overview
    case search
    case agenda
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

    private var agenda: AgendaSummary {
        store.agendaSummary(for: selectedDay)
    }

    private var selectedDayAnchor: Date {
        Calendar.autoupdatingCurrent.startOfDay(for: selectedDay)
    }

    private var primarySections: [LUUMSection] {
        [.overview, .search, .agenda, .apps, .websites, .team]
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
                        .frame(width: 296, alignment: .topLeading)

                    detailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 22)
                .padding(.top, 56)
                .padding(.bottom, 18)
            } else {
                LoginRequiredView(store: store)
                    .padding(40)
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

                SidebarSectionCard(title: "Fluxo do dia", subtitle: "Navegue pelo que voce quer entender agora.") {
                    VStack(spacing: 8) {
                        ForEach(primarySections) { section in
                            Button {
                                selection = section
                            } label: {
                                SidebarButtonRow(section: section, isSelected: selection == section, isLocked: !store.canUse(section.requiredFeature))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SidebarSectionCard(title: "Ajustes", subtitle: "Controles do motor do luum.") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(controlSections) { section in
                            Button {
                                selection = section
                            } label: {
                                SidebarToolTile(section: section, isSelected: selection == section, isLocked: !store.canUse(section.requiredFeature))
                            }
                            .buttonStyle(.plain)
                        }
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
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(LuumTheme.accent)

            VStack(spacing: 8) {
                Text("Entre no Luum")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("Use a mesma conta Firebase do site para liberar seu plano, backup e integracoes neste Mac. O app salva a sessao em um cofre local cifrado para evitar prompts do Keychain em builds ad-hoc.")
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [LuumTheme.accent, LuumTheme.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("luum")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Plano \(store.accountPlan.title) • \(store.isMonitoring ? "monitorando" : "pausado")")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                }

                Spacer()

                Circle()
                    .fill(store.isMonitoring ? ActivityCategory.work.tint : LuumTheme.textMuted)
                    .frame(width: 9, height: 9)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(store.currentActivityTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(store.currentActivityCategory?.title ?? "Aguardando classificacao")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.currentActivityCategory?.tint ?? LuumTheme.electricBlue)
            }

            HStack(spacing: 12) {
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
            } else if let focusShieldStatusMessage = store.focusShieldStatusMessage {
                Text(focusShieldStatusMessage)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .fixedSize(horizontal: false, vertical: true)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.14), cornerRadius: 28, shadowOpacity: 0.14)
    }
}

private struct SidebarSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LuumTheme.textMuted)
                    .tracking(1.1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(14)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 24, shadowOpacity: 0.14)
    }
}

private struct SidebarButtonRow: View {
    let section: LUUMSection
    let isSelected: Bool
    var isLocked = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.systemImage)
                .frame(width: 18)
                .foregroundStyle(isSelected ? .white : LuumTheme.textSecondary)

            Text(section.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : LuumTheme.textSecondary)

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LuumTheme.textMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? LuumTheme.accent.opacity(0.14) : LuumTheme.panelFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? LuumTheme.surfaceInnerHighlight : .white.opacity(0.02))
        }
    }
}

private struct SidebarToolTile: View {
    let section: LUUMSection
    let isSelected: Bool
    var isLocked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: section.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : LuumTheme.textSecondary)
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LuumTheme.textMuted)
                }
            }

            Text(section.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : LuumTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? LuumTheme.accent.opacity(0.14) : LuumTheme.panelFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? LuumTheme.surfaceInnerHighlight : .white.opacity(0.02))
        }
    }
}

private struct SidebarUtilityCard: View {
    let isMonitoring: Bool
    let currentActivity: String
    let category: ActivityCategory?
    let totalTrackedTime: TimeInterval
    let plannedTime: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label(
                    isMonitoring ? "Captura ativa" : "Captura pausada",
                    systemImage: isMonitoring ? "waveform.path.ecg" : "pause.circle"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isMonitoring ? ActivityCategory.work.tint : LuumTheme.textSecondary)

                Spacer()
            }

            Text(currentActivity)
                .foregroundStyle(.white.opacity(0.88))
                .font(.caption)
                .lineLimit(2)

            if let category {
                Label(category.title, systemImage: category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(category.tint)
            }

            HStack(spacing: 12) {
                SidebarMetricPill(title: "Capturado", value: LuumFormatters.duration(totalTrackedTime))
                SidebarMetricPill(title: "Agenda", value: LuumFormatters.duration(plannedTime))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .fixedSize(horizontal: false, vertical: true)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12), cornerRadius: 24, shadowOpacity: 0.1)
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
                .tracking(1.0)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
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
