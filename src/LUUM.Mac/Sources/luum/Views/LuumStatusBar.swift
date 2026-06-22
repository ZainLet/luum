import SwiftUI

struct LuumStatusBar: View {
    let store: ActivityStore

    private let barCount = 34

    var body: some View {
        HStack(spacing: 20) {
            monitoringIndicator
            Spacer(minLength: 0)
            activityWaveform
            Spacer(minLength: 0)
            sessionTimer
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

    private var monitoringIndicator: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(store.isMonitoring ? LuumTheme.cyanGreen.opacity(0.18) : .clear)
                    .frame(width: 18, height: 18)
                    .animation(.easeInOut(duration: 0.5), value: store.isMonitoring)

                Circle()
                    .fill(store.isMonitoring ? LuumTheme.cyanGreen : LuumTheme.textMuted)
                    .frame(width: 7, height: 7)
                    .shadow(color: store.isMonitoring ? LuumTheme.cyanGreen.opacity(0.8) : .clear, radius: 5)
                    .animation(.easeInOut(duration: 0.4), value: store.isMonitoring)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(store.isMonitoring ? "Capturando" : "Pausado")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.isMonitoring ? .white : LuumTheme.textSecondary)
                    .animation(.easeInOut(duration: 0.3), value: store.isMonitoring)

                Text(
                    store.currentActivityCategory?.title
                        ?? (store.isMonitoring ? "Classificando..." : "Nenhuma atividade")
                )
                .font(.caption2)
                .foregroundStyle(store.currentActivityCategory?.tint ?? LuumTheme.textMuted)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.3), value: store.currentActivityCategory?.title)
            }
        }
        .frame(width: 175, alignment: .leading)
    }

    private var activityWaveform: some View {
        TimelineView(.animation(minimumInterval: 0.07, paused: !store.isMonitoring)) { context in
            let t = store.isMonitoring ? context.date.timeIntervalSinceReferenceDate : 0
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let phase = t * 5.5 + Double(i) * 0.55
                    let raw = store.isMonitoring
                        ? abs(sin(phase)) * 0.52 + abs(sin(phase * 1.8 + 0.9)) * 0.48
                        : 0.12
                    let h = CGFloat(raw) * 26 + 5
                    Capsule()
                        .fill(
                            store.isMonitoring
                                ? LuumTheme.accent.opacity(0.32 + raw * 0.68)
                                : LuumTheme.textMuted.opacity(0.16)
                        )
                        .frame(width: 3, height: h)
                }
            }
            .frame(height: 38)
        }
    }

    private var sessionTimer: some View {
        HStack(spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(LuumFormatters.duration(store.currentActivityDuration))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

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
                                ? LuumTheme.hotPink.opacity(0.50)
                                : LuumTheme.accent.opacity(0.60),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: store.isMonitoring)
        }
        .frame(width: 210, alignment: .trailing)
    }
}
