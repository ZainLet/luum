import SwiftUI

struct LuumBackdrop: View {
    var body: some View {
        ZStack {
            LuumTheme.pageGradient
                .ignoresSafeArea()

            Circle()
                .fill(LuumTheme.accent.opacity(0.18))
                .frame(width: 520, height: 520)
                .blur(radius: 180)
                .offset(x: 420, y: 240)

            Circle()
                .fill(LuumTheme.secondaryAccent.opacity(0.17))
                .frame(width: 560, height: 560)
                .blur(radius: 200)
                .offset(x: -420, y: -260)

            Ellipse()
                .fill(LuumTheme.electricBlue.opacity(0.08))
                .frame(width: 880, height: 260)
                .blur(radius: 120)
                .offset(x: 0, y: -340)

            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.07),
                            .clear,
                            LuumTheme.accent.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(18)
                .ignoresSafeArea()
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
                .foregroundStyle(LuumTheme.textMuted)
                .tracking(1.9)

            Text(title)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.body)
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
                    .fill(LuumTheme.elevatedBlack.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.36), radius: 28, x: 0, y: 22)
                    .shadow(color: tint.opacity(shadowOpacity), radius: 26, x: 0, y: 16)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        LuumTheme.panelFillStrong,
                                        LuumTheme.panelFill,
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.09),
                                        .clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .mask {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                LuumTheme.surfaceInnerHighlight,
                                .white.opacity(0.03),
                                tint.opacity(0.18),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .glassEffect(
                .regular.tint(tint.opacity(0.16)).interactive(),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}
