import SwiftUI

struct FeedbackView: View {
    let store: ActivityStore

    @State private var message = ""
    @State private var state: SendState = .idle
    @Environment(\.dismiss) private var dismiss

    enum SendState: Equatable { case idle, sending, success, failure(String) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reportar problema")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Descreva o que aconteceu. Informações do sistema (versão do app, macOS) são enviadas automaticamente.")
                    .font(.subheadline)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextEditor(text: $message)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 140, maxHeight: 200)
                .background(LuumTheme.elevatedBlack)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08))
                )
                .overlay(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("Ex: o app travou ao mudar de aba, o timer parou de contar...")
                            .font(.body)
                            .foregroundStyle(LuumTheme.textMuted)
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                }
                .disabled(state == .sending || state == .success)

            switch state {
            case .failure(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(LuumTheme.hotPink)
            case .success:
                Label("Relatório enviado. Obrigado!", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(LuumTheme.electricBlue)
            default:
                EmptyView()
            }

            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.bordered)
                    .disabled(state == .sending)

                Spacer()

                Button(action: send) {
                    if state == .sending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else if state == .success {
                        Label("Enviado", systemImage: "checkmark")
                    } else {
                        Text("Enviar")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || state == .sending || state == .success)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Color(red: 0.04, green: 0.03, blue: 0.08))
        .preferredColorScheme(.dark)
    }

    private func send() {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idToken = store.authSession?.idToken else {
            state = .failure("Faça login antes de enviar um relatório.")
            return
        }
        state = .sending
        Task {
            do {
                try await CrashReportService.sendFeedback(message: trimmed, idToken: idToken)
                state = .success
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            } catch {
                state = .failure("Falha ao enviar. Verifique sua conexão e tente novamente.")
            }
        }
    }
}
