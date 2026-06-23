import SwiftUI

@MainActor
struct OnboardingView: View {
    let store: ActivityStore
    let onComplete: () -> Void

    @State private var step = 0
    @State private var accessibilityGranted = false
    @State private var screenRecordingGranted = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            LuumBackdrop()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 40)

                Spacer()

                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: permissionsStep
                    case 2: accountStep
                    case 3: readyStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)

                Spacer()

                stepControls
                    .padding(.bottom, 48)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: — Progress

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? LuumTheme.accent : Color.white.opacity(0.15))
                    .frame(width: i == step ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.35), value: step)
            }
        }
    }

    // MARK: — Step controls

    private var stepControls: some View {
        HStack(spacing: 16) {
            if step > 0 {
                Button("Voltar") { withAnimation(.spring(response: 0.4)) { step -= 1 } }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }

            Spacer()

            if step == 2 && !store.isSignedIn {
                // account step — handled inside the step view
                EmptyView()
            } else {
                Button(step == totalSteps - 1 ? "Entrar no Luum" : "Próximo") {
                    advance()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
            }
        }
        .padding(.horizontal, 40)
    }

    private func advance() {
        if step == totalSteps - 1 {
            onComplete()
        } else {
            withAnimation(.spring(response: 0.4)) { step += 1 }
        }
    }

    // MARK: — Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LuumTheme.accent.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(LuumTheme.accent)
            }

            VStack(spacing: 12) {
                Text("Bem-vindo ao Luum")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Rastreamento automático de produtividade para macOS.\nEntenda onde vai o seu tempo — sem esforço manual.")
                    .font(.system(size: 16))
                    .foregroundStyle(LuumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: 28) {
                featurePill(icon: "eye.slash", label: "Privado por padrão")
                featurePill(icon: "bolt", label: "Automático")
                featurePill(icon: "chart.bar", label: "Insights reais")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }

    private func featurePill(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LuumTheme.accentLight)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LuumTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05), in: Capsule())
    }

    // MARK: — Step 1: Permissions

    private var permissionsStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 10) {
                Text("Permissões necessárias")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text("O Luum precisa de duas permissões para funcionar.\nVocê controla tudo e pode revogar quando quiser.")
                    .font(.system(size: 15))
                    .foregroundStyle(LuumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 16) {
                permissionRow(
                    icon: "accessibility",
                    title: "Acessibilidade",
                    description: "Detecta qual app está em foco e o título da janela ativa.",
                    granted: accessibilityGranted
                ) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { checkPermissions() }
                }

                permissionRow(
                    icon: "record.circle",
                    title: "Gravação de tela",
                    description: "Lê a URL da aba ativa no navegador para classificar o site.",
                    granted: screenRecordingGranted
                ) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { checkPermissions() }
                }
            }
            .padding(.horizontal, 8)

            if accessibilityGranted && screenRecordingGranted {
                Label("Tudo certo! Pode continuar.", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LuumTheme.emerald)
            }
        }
        .padding(.horizontal, 40)
        .onAppear { checkPermissions() }
    }

    private func permissionRow(icon: String, title: String, description: String,
                               granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(granted ? LuumTheme.emerald.opacity(0.15) : LuumTheme.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: granted ? "checkmark" : icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(granted ? LuumTheme.emerald : LuumTheme.accentLight)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(LuumTheme.textSecondary)
            }

            Spacer()

            if !granted {
                Button("Conceder") { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(LuumTheme.emerald)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func checkPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    // MARK: — Step 2: Account

    private var accountStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text(store.isSignedIn ? "Conta conectada" : "Entre na sua conta")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text(store.isSignedIn
                     ? "Você já está conectado como \(store.accountEmail)."
                     : "Conecte sua conta para sincronizar dados e acessar todos os recursos.")
                    .font(.system(size: 15))
                    .foregroundStyle(LuumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if store.isSignedIn {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                        .font(.system(size: 36))
                        .foregroundStyle(LuumTheme.emerald)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.accountEmail)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Plano \(store.accountPlan.title)")
                            .font(.system(size: 13))
                            .foregroundStyle(LuumTheme.textSecondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LuumTheme.emerald.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Próximo") { advance() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return)

            } else {
                VStack(spacing: 12) {
                    Button {
                        if let url = URL(string: "https://luum-app.vercel.app/login?redirect=luum://auth") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Entrar com conta Luum", systemImage: "person.crop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)

                    Button("Continuar sem conta") { advance() }
                        .buttonStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(LuumTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: — Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(LuumTheme.emerald.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(LuumTheme.emerald)
            }

            VStack(spacing: 12) {
                Text("Tudo pronto!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text("O Luum vai começar a monitorar sua atividade automaticamente.\nVocê pode pausar ou ajustar a qualquer momento.")
                    .font(.system(size: 16))
                    .foregroundStyle(LuumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 12) {
                tipRow(icon: "menubar.rectangle", text: "O ícone na barra de menu mostra sua atividade atual")
                tipRow(icon: "keyboard.badge.ellipsis", text: "⌘⇧M pausa e retoma o monitoramento")
                tipRow(icon: "person.crop.circle", text: "Configure categorias e metas em Preferências")
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 40)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(LuumTheme.accentLight)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(LuumTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
