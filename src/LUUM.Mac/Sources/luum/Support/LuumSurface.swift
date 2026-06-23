import AppKit
import SwiftUI

struct LuumBackdrop: View {
    var body: some View {
        LuumTheme.baseBlack
            .ignoresSafeArea()
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LuumTheme.textMuted)
                .tracking(1.4)

            Text(title)
                .font(.system(size: 33, weight: .bold))
                .foregroundStyle(.white)
                .tracking(-0.5)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    /// Card padrão Luum — fill sutil + borda translúcida + raio 16 pt.
    func luumCard(
        tint: Color = .clear,
        cornerRadius: CGFloat = 16
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LuumTheme.panelFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(LuumTheme.surfaceOutline, lineWidth: 1)
            }
    }

    /// Card glass com glassEffect (macOS 26+), mantido para elementos premium.
    func luumGlassCard(
        tint: Color,
        cornerRadius: CGFloat = 16,
        shadowOpacity: Double = 0.16
    ) -> some View {
        let radius = min(cornerRadius, 20)
        return self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LuumTheme.elevatedBlack.opacity(0.85))
                    .shadow(color: Color.black.opacity(shadowOpacity), radius: 10, x: 0, y: 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.10),
                                .white.opacity(0.03),
                                tint.opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .glassEffect(
                .regular.tint(tint.opacity(0.07)).interactive(),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
    }
}
