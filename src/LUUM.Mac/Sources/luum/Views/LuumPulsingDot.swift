import SwiftUI

/// Indicador de estado ativo com anel pulsante.
/// Usa Core Animation via `repeatForever` — zero CPU, 0% de carga no main thread.
struct LuumPulsingDot: View {
    let isActive: Bool
    let color: Color
    var size: CGFloat = 8

    // O ring ocupa a mesma área que o dot (size × size); a animação cresce além disso.
    // Usamos um container ligeiramente maior para acomodar o halo.
    private var containerSize: CGFloat { size * 3.2 }

    var body: some View {
        ZStack {
            if isActive {
                PingRing(color: color, dotSize: size)
            }
            Circle()
                .fill(isActive ? color : LuumTheme.textMuted)
                .frame(width: size, height: size)
                .shadow(color: isActive ? color.opacity(0.65) : .clear, radius: size * 0.6)
                .animation(.easeInOut(duration: 0.35), value: isActive)
        }
        .frame(width: containerSize, height: containerSize)
    }
}

/// Anel separado: `.onAppear` dispara toda vez que `isActive` passa a `true`,
/// reiniciando a animação limpa. Core Animation lida com o loop — zero CPU.
private struct PingRing: View {
    let color: Color
    let dotSize: CGFloat

    @State private var expanding = false

    var body: some View {
        Circle()
            .fill(color.opacity(expanding ? 0 : 0.40))
            .frame(width: dotSize, height: dotSize)
            .scaleEffect(expanding ? 3.8 : 1.0)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    expanding = true
                }
            }
            .onDisappear {
                expanding = false
            }
    }
}
