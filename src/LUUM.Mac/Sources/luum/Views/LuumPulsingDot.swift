import SwiftUI

/// Indicador de estado ativo com anel pulsante.
/// Usa Core Animation via `repeatForever` — zero CPU, 0% de carga no main thread.
struct LuumPulsingDot: View {
    let isActive: Bool
    let color: Color
    var size: CGFloat = 8

    private var ringSize: CGFloat { size * 2.6 }

    var body: some View {
        ZStack {
            if isActive {
                PingRing(color: color, ringSize: ringSize)
            }
            Circle()
                .fill(isActive ? color : LuumTheme.textMuted)
                .frame(width: size, height: size)
                .shadow(color: isActive ? color.opacity(0.65) : .clear, radius: size * 0.6)
                .animation(.easeInOut(duration: 0.35), value: isActive)
        }
        .frame(width: ringSize, height: ringSize)
    }
}

/// Anel separado para que o `.onAppear` seja chamado toda vez que `isActive` liga.
private struct PingRing: View {
    let color: Color
    let ringSize: CGFloat

    @State private var expanding = false

    var body: some View {
        Circle()
            .fill(color.opacity(expanding ? 0 : 0.38))
            .frame(width: ringSize, height: ringSize)
            .scaleEffect(expanding ? 1.0 : 0.42)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    expanding = true
                }
            }
            .onDisappear {
                expanding = false
            }
    }
}
