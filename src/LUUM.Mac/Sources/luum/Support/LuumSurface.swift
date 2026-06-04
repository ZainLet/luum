import AppKit
import SwiftUI

struct LuumBackdrop: View {
    var body: some View {
        ZStack {
            LuumTheme.pageGradient
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .white.opacity(0.035),
                    .clear,
                    .black.opacity(0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Rectangle()
                    .fill(.white.opacity(0.035))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(.white.opacity(0.04))
                    .frame(height: 1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .ignoresSafeArea()

            HStack(spacing: 0) {
                Rectangle()
                    .fill(.white.opacity(0.035))
                    .frame(width: 1)
                Spacer()
                Rectangle()
                    .fill(.white.opacity(0.035))
                    .frame(width: 1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .ignoresSafeArea()
        }
    }
}

struct LuumAppMark: View {
    var size: CGFloat = 28

    var body: some View {
        Image(nsImage: appIcon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
    }

    private var appIcon: NSImage {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            return image
        }

        return NSApplication.shared.applicationIconImage
    }
}

struct LuumSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LuumTheme.textMuted)
                .tracking(1.2)

            Text(title)
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.callout)
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
        let radius = min(cornerRadius, 18)
        return self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LuumTheme.elevatedBlack.opacity(0.88))
                    .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 14)
                    .shadow(color: tint.opacity(min(shadowOpacity, 0.12)), radius: 12, x: 0, y: 8)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        LuumTheme.panelFill,
                                        .white.opacity(0.012),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.055),
                                        .clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .mask {
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                            }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.105),
                                .white.opacity(0.03),
                                tint.opacity(0.12),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .glassEffect(
                .regular.tint(tint.opacity(0.08)).interactive(),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
    }
}
