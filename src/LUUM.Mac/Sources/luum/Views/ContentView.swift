import AppKit
import SwiftUI

private enum LUUMSection: String, CaseIterable, Identifiable {
    case overview
    case agenda
    case apps
    case websites
    case categories
    case reminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Resumo"
        case .agenda:
            "Agenda"
        case .apps:
            "Apps"
        case .websites:
            "Sites"
        case .categories:
            "Categorias"
        case .reminders:
            "Lembretes"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            "rectangle.stack.fill"
        case .agenda:
            "calendar.badge.clock"
        case .apps:
            "app.connected.to.app.below.fill"
        case .websites:
            "globe"
        case .categories:
            "square.grid.2x2.fill"
        case .reminders:
            "bell.badge.fill"
        }
    }
}

struct ContentView: View {
    let store: ActivityStore

    @State private var selection: LUUMSection = .overview
    @State private var selectedDay = Date()

    private var summary: DailySummary {
        store.summary(for: selectedDay)
    }

    private var agenda: AgendaSummary {
        store.agendaSummary(for: selectedDay)
    }

    private var selectedDayAnchor: Date {
        Calendar.autoupdatingCurrent.startOfDay(for: selectedDay)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ZStack {
                LuumBackdrop()

                switch selection {
                case .overview:
                    DashboardView(store: store, selectedDay: selectedDay, summary: summary, agenda: agenda)
                case .agenda:
                    AgendaView(store: store, selectedDay: selectedDay, agenda: agenda)
                case .apps:
                    BreakdownListView(
                        title: "Tempo por aplicativo",
                        subtitle: "Os apps mais presentes do dia ficam organizados em um painel mais limpo e util para revisar horas investidas.",
                        emptyState: "Nenhum aplicativo rastreado neste dia.",
                        items: summary.appBreakdown
                    )
                case .websites:
                    BreakdownListView(
                        title: "Tempo por site",
                        subtitle: "As URLs do navegador ajudam o luum a separar trabalho de entretenimento com muito mais contexto.",
                        emptyState: "Nenhum site rastreado neste dia. Abra um navegador suportado e permita Automacao.",
                        items: summary.websiteBreakdown
                    )
                case .categories:
                    CategoryCustomizationView(store: store, summary: summary)
                case .reminders:
                    RemindersView(store: store)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Luum")
                    .font(.title3.weight(.semibold))
            }

            ToolbarItemGroup(placement: .primaryAction) {
                DatePicker("Dia", selection: $selectedDay, displayedComponents: .date)
                    .labelsHidden()

                if store.isGoogleCalendarConnected {
                    Button {
                        store.refreshGoogleCalendar(for: selectedDay)
                    } label: {
                        Label("Sincronizar agenda", systemImage: "arrow.triangle.2.circlepath")
                    }
                } else {
                    Button {
                        selection = .agenda
                    } label: {
                        Label("Conectar agenda", systemImage: "calendar.badge.plus")
                    }
                }

                Button(store.isMonitoring ? "Pausar" : "Monitorar") {
                    store.toggleMonitoring()
                }
                .buttonStyle(.glassProminent)

                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Preferencias", systemImage: "slider.horizontal.3")
                }
            }
        }
        .task(id: selectedDayAnchor) {
            await store.ensureAgenda(for: selectedDay)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            SidebarHero(store: store, summary: summary, agenda: agenda)

            VStack(spacing: 8) {
                ForEach(LUUMSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        SidebarButtonRow(section: section, isSelected: selection == section)
                    }
                    .buttonStyle(.plain)
                }
            }

            SidebarMonitoringCard(
                isMonitoring: store.isMonitoring,
                currentActivity: store.currentActivityTitle,
                category: store.currentActivityCategory,
                totalTrackedTime: summary.totalTrackedTime,
                plannedTime: agenda.plannedTime
            )

            Spacer()

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("Abrir Preferencias", systemImage: "gearshape")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(LuumTheme.textSecondary)
        }
        .padding(18)
        .frame(minWidth: 290)
    }
}

private struct SidebarHero: View {
    let store: ActivityStore
    let summary: DailySummary
    let agenda: AgendaSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [LuumTheme.accent, LuumTheme.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("luum")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Focus intelligence")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                }
            }

            Text(store.currentActivityTitle)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(spacing: 12) {
                SidebarStat(title: "Hoje", value: LuumFormatters.duration(summary.totalTrackedTime))
                SidebarStat(title: "Agenda", value: LuumFormatters.duration(agenda.plannedTime))
            }
        }
        .padding(18)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.16), cornerRadius: 30)
    }
}

private struct SidebarButtonRow: View {
    let section: LUUMSection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.systemImage)
                .frame(width: 18)
                .foregroundStyle(isSelected ? .white : LuumTheme.textSecondary)

            Text(section.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : LuumTheme.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? LuumTheme.accent.opacity(0.18) : .white.opacity(0.02))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? .white.opacity(0.08) : .clear)
        }
    }
}

private struct SidebarMonitoringCard: View {
    let isMonitoring: Bool
    let currentActivity: String
    let category: ActivityCategory?
    let totalTrackedTime: TimeInterval
    let plannedTime: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monitoramento")
                .font(.headline)
                .foregroundStyle(.white)

            Text(isMonitoring ? "Captura ativa" : "Captura pausada")
                .foregroundStyle(isMonitoring ? ActivityCategory.work.tint : LuumTheme.textSecondary)
                .font(.subheadline.weight(.semibold))

            Text(currentActivity)
                .foregroundStyle(LuumTheme.textSecondary)
                .font(.caption)
                .lineLimit(2)

            if let category {
                Label(category.title, systemImage: category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(category.tint)
            }

            Divider()
                .overlay(.white.opacity(0.06))

            SidebarStat(title: "Capturado", value: LuumFormatters.duration(totalTrackedTime))
            SidebarStat(title: "Planejado", value: LuumFormatters.duration(plannedTime))
        }
        .padding(18)
        .luumGlassCard(tint: ActivityCategory.utilities.glassTint, cornerRadius: 30, shadowOpacity: 0.18)
    }
}

private struct SidebarStat: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(LuumTheme.textSecondary)
                .font(.caption)

            Spacer()

            Text(value)
                .foregroundStyle(.white)
                .font(.caption.weight(.semibold))
        }
    }
}
