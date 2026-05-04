import SwiftUI

struct AgendaView: View {
    let store: ActivityStore
    let selectedDay: Date
    let agenda: AgendaSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LuumSectionHeader(
                    eyebrow: "Agenda",
                    title: "Google Calendar em contexto",
                    subtitle: "Agora o luum pode cruzar varias contas e varios calendarios para comparar melhor o que estava planejado com o que realmente tomou seu dia."
                )

                agendaStatusCard

                if !agenda.connections.isEmpty {
                    connectionsCard
                }

                if agenda.events.isEmpty {
                    emptyAgendaCard
                } else {
                    upcomingCard

                    VStack(spacing: 12) {
                        ForEach(agenda.events) { event in
                            AgendaRow(event: event)
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
                    Text(agenda.isConnected ? "Contas conectadas" : "Setup da agenda")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(agenda.isConnected
                         ? "\(agenda.connectedAccountCount) conta(s) e \(agenda.selectedCalendarCount) calendario(s) ativos neste Mac."
                         : "Conecte uma ou mais contas Google nas preferencias para liberar o sync multi-calendario.")
                        .foregroundStyle(LuumTheme.textSecondary)
                }

                Spacer()

                if agenda.isConnected {
                    Button("Sincronizar agora") {
                        store.refreshGoogleCalendar(for: selectedDay)
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button("Conectar Google Agenda") {
                        store.connectGoogleCalendar(for: selectedDay)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!agenda.isConfigured || store.isConnectingGoogleCalendar)
                }
            }

            if let message = store.googleCalendarStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12))
    }

    private var connectionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fontes ativas")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ForEach(agenda.connections) { connection in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(connection.profile.name)
                            .foregroundStyle(.white)
                            .font(.headline)

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

            Link("Abrir guia oficial do Google para OAuth desktop", destination: URL(string: "https://developers.google.com/identity/protocols/oauth2/native-app")!)
                .foregroundStyle(LuumTheme.electricBlue)
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

    private var emptyStateTitle: String {
        if !agenda.isConfigured {
            return "A agenda ainda nao foi configurada."
        }

        if !agenda.isConnected {
            return "A configuracao esta pronta, falta conectar."
        }

        return "Sem compromissos para o dia selecionado."
    }

    private var emptyStateDescription: String {
        if !agenda.isConfigured {
            return "Nas preferencias do luum voce pode colar o Client ID do Google Cloud e ativar o sync desktop com multiplas contas."
        }

        if !agenda.isConnected {
            return "Depois de conectar, o luum lista os calendarios de cada conta para voce decidir o que entra na timeline."
        }

        return "Troque a data no topo ou sincronize novamente para verificar outros dias."
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
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
