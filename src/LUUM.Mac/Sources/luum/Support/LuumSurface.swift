import SwiftUI

struct LuumBackdrop: View {
    var body: some View {
        ZStack {
            LuumTheme.pageGradient
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .white.opacity(0.05),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            Circle()
                .fill(LuumTheme.accent.opacity(0.15))
                .frame(width: 420, height: 420)
                .blur(radius: 140)
                .offset(x: -320, y: -220)

            Circle()
                .fill(LuumTheme.secondaryAccent.opacity(0.16))
                .frame(width: 520, height: 520)
                .blur(radius: 160)
                .offset(x: 360, y: 120)

            Ellipse()
                .fill(LuumTheme.secondaryAccent.opacity(0.08))
                .frame(width: 760, height: 300)
                .blur(radius: 90)
                .offset(x: 180, y: -260)
        }
    }
}

struct LuumSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .tracking(1.4)

            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.title3)
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    func luumGlassCard(
        tint: Color,
        cornerRadius: CGFloat = 30,
        shadowOpacity: Double = 0.24
    ) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.012))
                    .shadow(color: tint.opacity(shadowOpacity), radius: 20, x: 0, y: 10)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.04),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.06))
            }
            .glassEffect(.regular.tint(tint).interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
