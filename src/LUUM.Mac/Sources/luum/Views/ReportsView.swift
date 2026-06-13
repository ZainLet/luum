import SwiftUI

struct ReportsView: View {
    @Bindable var store: ActivityStore
    let selectedDay: Date

    var body: some View {
        let report = store.weeklyReport(containing: selectedDay)

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Relatorios",
                    title: "Visao semanal pronta para decisao",
                    subtitle: "Acompanhe o ritmo da semana, o foco real, as trocas de contexto e exporte um retrato do uso do luum em CSV ou JSON."
                )

                summaryCard(report: report)
                highlightsCard(report: report)
                goalsCard(report: report)
                breakdownCard(title: "Top categorias", items: report.topCategories.prefix(8).map { ($0.category.title, LuumFormatters.duration($0.duration), $0.category.tint) })
                breakdownCard(title: "Top apps", items: report.topApps.prefix(12).map { ($0.label, LuumFormatters.duration($0.duration), $0.category?.tint ?? LuumTheme.accent) })
                breakdownCard(title: "Top sites", items: report.topSites.prefix(12).map { ($0.label, LuumFormatters.duration($0.duration), $0.category?.tint ?? LuumTheme.electricBlue) })
                exportCard
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }

    private func summaryCard(report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Semana de \(report.startDate.formatted(.dateTime.day().month(.abbreviated))) a \(report.endDate.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()
            }

            HStack(spacing: 14) {
                ReportMetricCard(title: "Tempo total", value: LuumFormatters.duration(report.totalTrackedTime), tint: LuumTheme.accent)
                ReportMetricCard(title: "Media diaria", value: LuumFormatters.duration(report.averageDailyTrackedTime), tint: LuumTheme.electricBlue)
                ReportMetricCard(title: "Trocas", value: "\(report.contextSwitches)", tint: LuumTheme.hotPink)
                ReportMetricCard(title: "Foco", value: LuumFormatters.duration(report.focusTime), tint: LuumTheme.secondaryAccent)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 30)
    }

    private func highlightsCard(report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Destaques")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ForEach(report.highlights, id: \.self) { item in
                Text(item)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(0.03))
                    )
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12), cornerRadius: 30)
    }

    private func goalsCard(report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Metas")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if report.goalProgress.isEmpty {
                Text("Nenhuma meta ativa para comparar nesta semana.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                ForEach(report.goalProgress) { progress in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(progress.goal.title)
                                .foregroundStyle(.white)
                            Text("\(progress.category.title) • \(progress.goal.period.title)")
                                .foregroundStyle(LuumTheme.textSecondary)
                                .font(.caption)
                        }

                        Spacer()

                        Text(progress.isMet ? "No alvo" : "Fora do alvo")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(progress.isMet ? LuumTheme.electricBlue : LuumTheme.hotPink)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(0.03))
                    )
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12), cornerRadius: 30)
    }

    private func breakdownCard(title: String, items: [(String, String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if items.isEmpty {
                Text("Sem dados suficientes.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Circle()
                            .fill(item.2)
                            .frame(width: 10, height: 10)

                        Text(item.0)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        Text(item.1)
                            .foregroundStyle(item.2)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(0.03))
                    )
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.1), cornerRadius: 30)
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exportacao")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Os arquivos saem em `Downloads/luum-exports` para voce usar em backup, analise externa ou IA.")
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Exportar JSON") {
                    store.exportWeeklyReport(containing: selectedDay, format: .json)
                }
                .buttonStyle(.glassProminent)

                Button("Exportar CSV") {
                    store.exportWeeklyReport(containing: selectedDay, format: .csv)
                }
                .buttonStyle(.borderedProminent)

                Button(store.isSendingWeeklyReportEmail ? "Enviando..." : "Enviar PDF por email") {
                    store.emailWeeklyReport(containing: selectedDay)
                }
                .buttonStyle(.bordered)
                .disabled(store.isSendingWeeklyReportEmail || !store.canUse(.weeklyReportEmail))
            }

            if let exportStatusMessage = store.exportStatusMessage {
                Text(exportStatusMessage)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12), cornerRadius: 30)
    }
}

private struct ReportMetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LuumTheme.textMuted)
                .tracking(1.1)

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}
