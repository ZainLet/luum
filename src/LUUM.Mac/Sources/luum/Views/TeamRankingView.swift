import SwiftUI

struct TeamRankingView: View {
    @Bindable var store: ActivityStore
    let selectedDay: Date

    private var entries: [TeamRankingEntry] {
        store.teamRanking(for: selectedDay)
    }

    private var currentUserEntry: TeamRankingEntry? {
        entries.first(where: \.isCurrentUser)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Equipe",
                    title: "Ranking e comparativos",
                    subtitle: "Uma visão inspirada em vendas B2B: acompanhe ranking, foco, cobertura e trocas de contexto entre pessoas da mesma empresa."
                )

                overviewStrip
                rankingTable
                insightsCard
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }

    private var overviewStrip: some View {
        HStack(spacing: 16) {
            rankingMetricCard(
                title: store.teamSettings.organizationName,
                value: store.teamRankingUsesPreviewData ? "Preview" : "Ao vivo",
                detail: store.teamRankingUsesPreviewData ? "modelo de equipe para demo" : "comparacao real da equipe",
                tint: LuumTheme.accent
            )

            rankingMetricCard(
                title: "Seu score",
                value: currentUserEntry.map { "\($0.score)" } ?? "--",
                detail: currentUserEntry.map { LuumFormatters.duration($0.focusTime) + " de foco" } ?? "aguardando dados",
                tint: LuumTheme.electricBlue
            )

            rankingMetricCard(
                title: "Meta semanal",
                value: currentUserEntry.map { LuumFormatters.duration($0.plannedTime) } ?? "--",
                detail: store.teamSettings.sharesAnonymousMetrics ? "participando da comparacao" : "comparacao privada",
                tint: LuumTheme.hotPink
            )
        }
    }

    private var rankingTable: some View {
        VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Leaderboard da semana")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    if !store.teamRankingUsesPreviewData, let lastSyncAt = store.workspaceSyncLastSyncAt {
                        Text("sync \(LuumFormatters.relativeTime(until: lastSyncAt))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LuumTheme.textMuted)
                    } else {
                        Text("preview de vendas")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LuumTheme.textMuted)
                    }
                }

            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    rankingHeader("Pessoa", width: 210, alignment: .leading)
                    rankingHeader("Foco", width: 110, alignment: .trailing)
                    rankingHeader("Capturado", width: 120, alignment: .trailing)
                    rankingHeader("Cobertura", width: 110, alignment: .trailing)
                    rankingHeader("Score", width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.03))
                )

                VStack(spacing: 10) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        TeamRankingRow(rank: index + 1, entry: entry)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 30)
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Leitura comercial e operacional")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(store.teamRankingUsesPreviewData
                 ? "Esta tela ainda está em modo preview. Conecte o workspace nas preferências para publicar seu snapshot semanal e receber o ranking real da equipe."
                 : "A comparação está usando dados reais compartilhados do workspace corporativo.")
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Use este painel para discutir foco, previsibilidade, distribuição de carga e sinais de burnout sem depender apenas de horas brutas.")
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.teamRankingUsesPreviewData {
                Button {
                    store.openLoginPage()
                } label: {
                    Label("Configurar workspace real", systemImage: "person.3.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LuumTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(LuumTheme.accent.opacity(0.12)))
                        .overlay(Capsule().stroke(LuumTheme.accent.opacity(0.30), lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let message = store.workspaceSyncStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.accent)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12), cornerRadius: 30)
    }

    private func rankingMetricCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.64))
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(detail)
                .foregroundStyle(tint)
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .luumGlassCard(tint: tint.opacity(0.14), cornerRadius: 28, shadowOpacity: 0.14)
    }

    private func rankingHeader(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(LuumTheme.textMuted)
            .frame(width: width, alignment: alignment)
    }
}

private struct TeamRankingRow: View {
    let rank: Int
    let entry: TeamRankingEntry

    private var coverageLabel: String {
        LuumFormatters.percentage(entry.trackedTime, over: entry.plannedTime)
    }

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(entry.isCurrentUser ? LuumTheme.accent.opacity(0.3) : .white.opacity(0.06))
                        .frame(width: 40, height: 40)

                    Text("\(rank)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(entry.isCurrentUser ? .white : LuumTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayName)
                        .foregroundStyle(.white)
                        .font(.headline)

                    Text(entry.roleLabel + (entry.isCurrentUser ? " • você" : ""))
                        .foregroundStyle(LuumTheme.textSecondary)
                        .font(.caption)
                }
            }
            .frame(width: 210, alignment: .leading)

            Text(LuumFormatters.duration(entry.focusTime))
                .frame(width: 110, alignment: .trailing)
                .foregroundStyle(LuumTheme.electricBlue)

            Text(LuumFormatters.duration(entry.trackedTime))
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(.white)

            Text(coverageLabel)
                .frame(width: 110, alignment: .trailing)
                .foregroundStyle(LuumTheme.textSecondary)

            Text("\(entry.score)")
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(entry.isCurrentUser ? LuumTheme.hotPink : LuumTheme.accent)
                .font(.headline.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(entry.isCurrentUser ? LuumTheme.accent.opacity(0.12) : .white.opacity(0.02))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(entry.isCurrentUser ? LuumTheme.accent.opacity(0.22) : .white.opacity(0.04))
        }
    }
}
