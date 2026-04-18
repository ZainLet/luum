import SwiftUI

struct LuumBackdrop: View {
    var body: some View {
        ZStack {
            LuumTheme.pageGradient
                .ignoresSafeArea()

            Circle()
                .fill(LuumTheme.accent.opacity(0.22))
                .frame(width: 520, height: 520)
                .blur(radius: 160)
                .offset(x: -360, y: -240)

            Circle()
                .fill(LuumTheme.secondaryAccent.opacity(0.24))
                .frame(width: 620, height: 620)
                .blur(radius: 180)
                .offset(x: 420, y: 180)

            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(.white.opacity(0.03))
                .frame(width: 760, height: 520)
                .overlay {
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .stroke(.white.opacity(0.08))
                }
                .blur(radius: 0.2)
                .rotationEffect(.degrees(-8))
                .offset(x: 260, y: 120)

            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.clear)
                .frame(width: 540, height: 360)
                .overlay {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(LuumTheme.accent.opacity(0.18))
                }
                .rotationEffect(.degrees(14))
                .offset(x: 430, y: -260)
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
                    .fill(.white.opacity(0.015))
                    .shadow(color: tint.opacity(shadowOpacity), radius: 32, x: 0, y: 18)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08))
            }
            .glassEffect(.regular.tint(tint).interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
