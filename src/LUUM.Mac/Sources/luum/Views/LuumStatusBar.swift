import SwiftUI

@MainActor
struct LuumStatusBar: View {
    let store: ActivityStore
    let summary: DailySummary

    var body: some View {
        HStack(spacing: 0) {
            liveIndicator
                .frame(width: 188, alignment: .leading)

            Spacer(minLength: 18)
            miniTimeline
            Spacer(minLength: 18)

            sessionControls
                .frame(width: 210, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Rectangle())
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LuumTheme.surfaceOutline)
                .frame(height: 0.5)
        }
    }

    // MARK: - Left: pulsing live dot + current state
    private var liveIndicator: some View {
        HStack(spacing: 10) {
            pulsingDot

            VStack(alignment: .leading, spacing: 2) {
                Text(store.isMonitoring ? "Capturando" : "Pausado")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.isMonitoring ? .white : LuumTheme.textSecondary)
                    .animation(.easeInOut(duration: 0.3), value: store.isMonitoring)

                Text(
                    store.currentActivityCategory?.title
                        ?? (store.isMonitoring ? "Classificando..." : "Sem atividade")
                )
                .font(.caption2)
                .foregroundStyle(store.currentActivityCategory?.tint ?? LuumTheme.textMuted)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.25), value: store.currentActivityCategory?.title)
            }
        }
    }

    private var pulsingDot: some View {
        LuumPulsingDot(isActive: store.isMonitoring, color: LuumTheme.cyanGreen, size: 8)
    }

    // MARK: - Center: mini horizontal activity timeline (today's category breakdown)
    private var miniTimeline: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("HOJE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(LuumTheme.textMuted)
                    .tracking(1.2)

                Spacer()

                if summary.totalTrackedTime > 0 {
                    Text(LuumFormatters.duration(summary.totalTrackedTime))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(LuumTheme.textMuted)
                }
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    if summary.categoryBreakdown.isEmpty {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LuumTheme.panelFillStrong)
                            .frame(maxWidth: .infinity)
                            .overlay {
                                Text(store.isMonitoring ? "Aguardando dados..." : "Monitoramento pausado")
                                    .font(.system(size: 9))
                                    .foregroundStyle(LuumTheme.textMuted)
                            }
                    } else {
                        let total = summary.categoryBreakdown.reduce(0) { $0 + $1.duration }
                        let availableWidth = geo.size.width

                        ForEach(summary.categoryBreakdown.prefix(7)) { bucket in
                            let fraction = CGFloat(bucket.duration / max(total, 1))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(bucket.category.tint.opacity(0.88))
                                .frame(width: max(5, fraction * availableWidth - 2))
                                .help("\(bucket.category.title) — \(LuumFormatters.duration(bucket.duration))")
                        }

                        // Gray remainder (untracked time vs 8h day)
                        let eightHours: TimeInterval = 28800
                        if total < eightHours {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LuumTheme.panelFillStrong)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: summary.categoryBreakdown.count)
            }
            .frame(height: 12)
        }
    }

    // MARK: - Right: timer + toggle button
    private var sessionControls: some View {
        HStack(spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(LuumFormatters.duration(store.currentActivityDuration))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("sessão atual")
                    .font(.caption2)
                    .foregroundStyle(LuumTheme.textMuted)
            }

            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    store.toggleMonitoring()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: store.isMonitoring ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(store.isMonitoring ? "Pausar" : "Iniciar sessão")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            store.isMonitoring
                                ? LuumTheme.hotPink.opacity(0.18)
                                : LuumTheme.accent.opacity(0.26)
                        )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            store.isMonitoring
                                ? LuumTheme.hotPink.opacity(0.52)
                                : LuumTheme.accent.opacity(0.62),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: store.isMonitoring)
        }
    }
}
