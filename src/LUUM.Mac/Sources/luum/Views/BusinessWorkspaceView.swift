import SwiftUI

struct BusinessWorkspaceView: View {
    @Bindable var store: ActivityStore

    @State private var clientNameDraft = ""
    @State private var clientDomainDraft = ""
    @State private var projectTitleDraft = ""
    @State private var selectedClientID: UUID?
    @State private var taskDrafts: [UUID: String] = [:]

    private var settings: BusinessWorkspaceSettings {
        store.businessSettings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LuumSectionHeader(
                    eyebrow: "Operacao",
                    title: "Clientes, projetos e tarefas",
                    subtitle: "Monte a base comercial que transforma rastreamento de tempo em rentabilidade, contratos e relatorios por cliente."
                )

                metricsRow
                addClientCard
                projectComposerCard
                clientsList
            }
            .padding(28)
        }
        .background(LuumTheme.pageGradient.opacity(0.48))
        .onAppear {
            selectedClientID = selectedClientID ?? settings.clients.first?.id
        }
    }

    private var metricsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 12)], spacing: 12) {
            BusinessMetricCard(title: "Clientes", value: "\(settings.activeClients.count)", detail: "ativos")
            BusinessMetricCard(title: "Projetos", value: "\(settings.activeProjects.count)", detail: "em andamento")
            BusinessMetricCard(title: "Faturaveis", value: "\(settings.billableProjectsCount)", detail: "com valor definido")
            BusinessMetricCard(title: "Retainer", value: currency(settings.estimatedMonthlyRevenue), detail: "mensal estimado")
        }
    }

    private var addClientCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Novo cliente")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                TextField("Nome do cliente", text: $clientNameDraft)
                    .textFieldStyle(.roundedBorder)

                TextField("Dominio ou site", text: $clientDomainDraft)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                store.addBusinessClient(name: clientNameDraft, domain: clientDomainDraft)
                selectedClientID = store.businessSettings.clients.first(where: { $0.name == clientNameDraft.trimmingCharacters(in: .whitespacesAndNewlines) })?.id ?? selectedClientID
                clientNameDraft = ""
                clientDomainDraft = ""
            } label: {
                Label("Adicionar cliente", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.glassProminent)
            .disabled(clientNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.14), cornerRadius: 28)
    }

    private var projectComposerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Novo projeto")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if settings.clients.isEmpty {
                Text("Adicione um cliente para criar projetos e tarefas.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                Picker("Cliente", selection: Binding(
                    get: { selectedClientID ?? settings.clients.first?.id },
                    set: { selectedClientID = $0 }
                )) {
                    ForEach(settings.clients) { client in
                        Text(client.name).tag(Optional(client.id))
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 12) {
                    TextField("Nome do projeto", text: $projectTitleDraft)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        guard let selectedClientID else { return }
                        store.addBusinessProject(clientID: selectedClientID, title: projectTitleDraft)
                        projectTitleDraft = ""
                    } label: {
                        Label("Criar projeto", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(projectTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedClientID == nil)
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: ActivityCategory.learning.glassTint.opacity(0.42), cornerRadius: 28)
    }

    private var clientsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Carteira")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if settings.clients.isEmpty {
                Text("Nenhum cliente cadastrado ainda.")
                    .foregroundStyle(LuumTheme.textSecondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .luumGlassCard(tint: Color.white.opacity(0.08), cornerRadius: 22)
            } else {
                ForEach(settings.clients) { client in
                    ClientBusinessCard(
                        store: store,
                        client: client,
                        projects: settings.projects.filter { $0.clientID == client.id },
                        taskDraft: Binding(
                            get: { taskDrafts[client.id] ?? "" },
                            set: { taskDrafts[client.id] = $0 }
                        )
                    )
                }
            }
        }
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0"
    }
}

private struct BusinessMetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LuumTheme.textMuted)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(detail)
                .font(.caption)
                .foregroundStyle(LuumTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(16)
        .luumGlassCard(tint: Color.white.opacity(0.08), cornerRadius: 20)
    }
}

private struct ClientBusinessCard: View {
    @Bindable var store: ActivityStore
    let client: WorkClientProfile
    let projects: [WorkProjectProfile]
    @Binding var taskDraft: String

    @State private var isEditing = false
    @State private var clientDraft: WorkClientProfile

    init(store: ActivityStore, client: WorkClientProfile, projects: [WorkProjectProfile], taskDraft: Binding<String>) {
        self.store = store
        self.client = client
        self.projects = projects
        self._taskDraft = taskDraft
        self._clientDraft = State(initialValue: client)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(client.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(client.domain.isEmpty ? "Sem dominio" : client.domain)
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                }

                Spacer()

                Text(client.contract.billingModel.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LuumTheme.electricBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(LuumTheme.electricBlue.opacity(0.12)))

                Button {
                    clientDraft = client
                    isEditing.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                .help("Editar cliente")

                Button(role: .destructive) {
                    store.removeBusinessClient(id: client.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Remover cliente")
            }

            if isEditing {
                editClientForm
            }

            if projects.isEmpty {
                Text("Sem projetos para este cliente.")
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textMuted)
            } else {
                VStack(spacing: 10) {
                    ForEach(projects) { project in
                        ProjectBusinessRow(store: store, project: project, taskDraft: $taskDraft)
                    }
                }
            }
        }
        .padding(20)
        .luumGlassCard(tint: Color.white.opacity(0.07), cornerRadius: 24)
    }

    private var editClientForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                TextField("Cliente", text: $clientDraft.name)
                    .textFieldStyle(.roundedBorder)

                TextField("Dominio", text: $clientDraft.domain)
                    .textFieldStyle(.roundedBorder)

                Picker("Modelo", selection: $clientDraft.contract.billingModel) {
                    ForEach(BusinessBillingModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }
                .pickerStyle(.menu)

                Picker("Periodo", selection: $clientDraft.contract.period) {
                    ForEach(ContractPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.menu)

                TextField("Retainer mensal", value: $clientDraft.contract.retainerAmount, format: .number)
                    .textFieldStyle(.roundedBorder)

                TextField("Valor hora padrao", value: $clientDraft.contract.defaultHourlyRate, format: .number)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                store.updateBusinessClient(clientDraft)
                isEditing = false
            } label: {
                Label("Salvar cliente", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct ProjectBusinessRow: View {
    @Bindable var store: ActivityStore
    let project: WorkProjectProfile
    @Binding var taskDraft: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(LuumTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(project.tasks.isEmpty ? "Nenhuma tarefa" : "\(project.tasks.count) tarefas")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                }

                Spacer()

                Button(role: .destructive) {
                    store.removeBusinessProject(id: project.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Remover projeto")
            }

            HStack(spacing: 10) {
                TextField("Adicionar tarefa", text: $taskDraft)
                    .textFieldStyle(.roundedBorder)

                Button {
                    store.addBusinessTask(projectID: project.id, title: taskDraft)
                    taskDraft = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .help("Adicionar tarefa")
                .disabled(taskDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !project.tasks.isEmpty {
                FlowTaskList(project: project, store: store)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.075)))
    }
}

private struct FlowTaskList: View {
    let project: WorkProjectProfile
    let store: ActivityStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(project.tasks) { task in
                HStack(spacing: 8) {
                    Image(systemName: task.isBillable ? "dollarsign.circle.fill" : "circle")
                        .foregroundStyle(task.isBillable ? LuumTheme.electricBlue : LuumTheme.textMuted)

                    Text(task.title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.86))

                    Spacer()

                    Button {
                        store.removeBusinessTask(projectID: project.id, taskID: task.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(LuumTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Remover tarefa")
                }
            }
        }
    }
}
