import SwiftUI

struct SettingsView: View {
    @Bindable var store: ActivityStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Preferencias",
                    title: "Centro de configuracao",
                    subtitle: "Ajuste permissoes, monitore o estado da captura e conecte a Google Agenda ao fluxo do luum."
                )

                googleCalendarCard

                settingsCard(
                    title: "Permissoes de navegador",
                    lines: [
                        "Safari, Chrome, Arc, Brave, Edge, Opera, Chromium e Vivaldi podem fornecer a URL da aba ativa.",
                        "O macOS pede permissao de Automacao na primeira tentativa de leitura.",
                        store.automationStatusMessage ?? "Nenhum erro recente de Automacao.",
                    ],
                    tint: ActivityCategory.communication.glassTint
                )

                settingsCard(
                    title: "Monitoramento de entrada",
                    lines: [
                        store.inputMonitoringMessage ?? "Permissao de Monitoramento de Entrada ativa. O luum consegue detectar inatividade.",
                        "Essa permissao e opcional: sem ela, o app continua monitorando apps e URLs normalmente.",
                    ],
                    tint: ActivityCategory.utilities.glassTint
                )

                settingsCard(
                    title: "Estado da captura",
                    lines: [
                        store.isMonitoring ? "Captura ativa em background." : "Captura pausada.",
                        "Apps acompanhados no historico: \(store.trackedAppsCount)",
                        "Sites enriquecidos no historico: \(store.trackedSitesCount)",
                    ],
                    tint: ActivityCategory.work.glassTint
                )

                actionRow
                classificationCard
            }
            .padding(28)
        }
        .background(LuumTheme.pageGradient.opacity(0.46))
    }

    private var googleCalendarCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Google Agenda")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Use um OAuth Client ID do tipo Desktop app para habilitar a sincronizacao do Google Calendar diretamente no macOS.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if store.isGoogleCalendarConnected {
                    Text("Conectado")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(LuumTheme.electricBlue.opacity(0.2))
                        )
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Client ID")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                TextField(
                    "1234567890-abcdef.apps.googleusercontent.com",
                    text: Binding(
                        get: { store.googleCalendarClientID },
                        set: { store.updateGoogleCalendarClientID($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Text("Client secret opcional")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                SecureField(
                    "Opcional para apps desktop",
                    text: Binding(
                        get: { store.googleCalendarClientSecret },
                        set: { store.updateGoogleCalendarClientSecret($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }

            if let message = store.googleCalendarStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button("Conectar Google Agenda") {
                    store.connectGoogleCalendar()
                }
                .buttonStyle(.glassProminent)
                .disabled(!store.isGoogleCalendarConfigured || store.isConnectingGoogleCalendar)

                Button("Sincronizar agenda") {
                    store.refreshGoogleCalendar()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.isGoogleCalendarConnected || store.isSyncingGoogleCalendar)

                Button("Desconectar") {
                    store.disconnectGoogleCalendar()
                }
                .buttonStyle(.bordered)
                .disabled(!store.isGoogleCalendarConnected)
            }

            HStack(spacing: 16) {
                Link("Criar credenciais no Google Cloud", destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
                Link("Guia oficial para OAuth desktop", destination: URL(string: "https://developers.google.com/identity/protocols/oauth2/native-app")!)
                Link("Escopos da Calendar API", destination: URL(string: "https://developers.google.com/workspace/calendar/api/auth")!)
            }
            .font(.caption)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.14), cornerRadius: 30)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button("Abrir Privacidade > Automacao") {
                SystemSettings.openAutomationPrivacy()
            }
            .buttonStyle(.glassProminent)

            Button("Solicitar monitoramento de entrada") {
                store.requestInputMonitoringAccess()
            }
            .buttonStyle(.borderedProminent)

            Button("Abrir pasta do historico") {
                SystemSettings.openActivityLogFolder()
            }
            .buttonStyle(.bordered)
        }
    }

    private var classificationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Classificacao inicial")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ForEach(store.rulePreviews) { preview in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: preview.category.systemImage)
                        .foregroundStyle(preview.category.tint)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preview.category.title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(preview.examples.joined(separator: ", "))
                            .foregroundStyle(LuumTheme.textSecondary)
                    }
                }
                .padding(16)
                .luumGlassCard(tint: preview.category.glassTint, cornerRadius: 26, shadowOpacity: 0.14)
            }
        }
    }

    private func settingsCard(title: String, lines: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .luumGlassCard(tint: tint, cornerRadius: 30)
    }
}
