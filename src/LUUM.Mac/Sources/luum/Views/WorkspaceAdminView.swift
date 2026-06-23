import SwiftUI

struct WorkspaceAdminView: View {
    @Bindable var store: ActivityStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.12)
            content
        }
        .frame(width: 560, height: 520)
        .background(Color(red: 0.06, green: 0.05, blue: 0.12))
        .onAppear { store.fetchWorkspaceAdminList() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gerenciar membros")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(store.teamSettings.organizationName)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textMuted)
            }
            Spacer()
            Button("Fechar") { dismiss() }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(LuumTheme.textSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var content: some View {
        Group {
            if store.isLoadingAdminList && store.workspaceAdminEntries.isEmpty {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Carregando membros...")
                        .font(.subheadline)
                        .foregroundStyle(LuumTheme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.workspaceAdminEntries.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(LuumTheme.textMuted)
                    Text("Nenhum membro encontrado")
                        .font(.subheadline)
                        .foregroundStyle(LuumTheme.textMuted)
                    Button("Tentar novamente") { store.fetchWorkspaceAdminList() }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LuumTheme.accent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                memberList
            }
        }
    }

    private var memberList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(store.workspaceAdminEntries) { entry in
                    AdminMemberRow(
                        entry: entry,
                        adminCount: store.workspaceAdminEntries.filter(\.isAdmin).count,
                        onPromote: { store.promoteWorkspaceMember(uid: entry.id) },
                        onDemote: { store.demoteWorkspaceMember(uid: entry.id) },
                        onRemove: { store.removeWorkspaceMember(uid: entry.id) }
                    )
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }
}

private struct AdminMemberRow: View {
    let entry: WorkspaceAdminEntry
    let adminCount: Int
    let onPromote: () -> Void
    let onDemote: () -> Void
    let onRemove: () -> Void

    private var isLastAdmin: Bool {
        entry.isAdmin && adminCount <= 1
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(entry.isCurrentUser ? LuumTheme.accent.opacity(0.3) : .white.opacity(0.07))
                    .frame(width: 40, height: 40)
                Text(String(entry.displayName.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(entry.isCurrentUser ? .white : LuumTheme.textSecondary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    if entry.isAdmin {
                        Text("Admin")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LuumTheme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(LuumTheme.accent.opacity(0.15)))
                            .overlay(Capsule().stroke(LuumTheme.accent.opacity(0.30), lineWidth: 1))
                    }

                    if entry.isCurrentUser {
                        Text("você")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LuumTheme.electricBlue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(LuumTheme.electricBlue.opacity(0.15)))
                            .overlay(Capsule().stroke(LuumTheme.electricBlue.opacity(0.30), lineWidth: 1))
                    }
                }
                Text(entry.roleLabel + " • score \(entry.score)")
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textMuted)
            }

            Spacer()

            // Actions
            if !entry.isCurrentUser {
                HStack(spacing: 8) {
                    if entry.isAdmin {
                        Button("Rebaixar") { onDemote() }
                            .buttonStyle(AdminActionButtonStyle(tint: LuumTheme.hotPink, enabled: !isLastAdmin))
                            .disabled(isLastAdmin)
                            .help(isLastAdmin ? "O workspace precisa ter ao menos um admin" : "Remover permissão de admin")
                    } else {
                        Button("Promover") { onPromote() }
                            .buttonStyle(AdminActionButtonStyle(tint: LuumTheme.accent, enabled: true))
                            .help("Conceder permissão de admin")
                    }

                    Button(role: .destructive) { onRemove() } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(AdminActionButtonStyle(tint: .red, enabled: true))
                    .help("Remover membro do workspace")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(entry.isCurrentUser ? LuumTheme.accent.opacity(0.07) : .white.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(entry.isCurrentUser ? LuumTheme.accent.opacity(0.18) : .white.opacity(0.05))
        }
    }
}

private struct AdminActionButtonStyle: ButtonStyle {
    let tint: Color
    let enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(enabled ? tint : LuumTheme.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(enabled ? (configuration.isPressed ? 0.25 : 0.12) : 0.05)))
            .overlay(Capsule().stroke(tint.opacity(enabled ? 0.30 : 0.10), lineWidth: 1))
            .contentShape(Capsule())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
