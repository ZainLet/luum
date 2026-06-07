import SwiftUI

struct FocusModesView: View {
    @Bindable var store: ActivityStore
    let selectedDay: Date

    @State private var newGoalTitle = ""
    @State private var newGoalCategoryID = ActivityCategory.work.id
    @State private var newGoalTargetMinutes = 180
    @State private var newGoalPeriod: GoalPeriod = .daily
    @State private var newGoalDirection: GoalDirection = .atLeast

    @State private var newProfileTitle = ""
    @State private var newProfileKind: FocusModeKind = .focus
    @State private var newProfileThresholdMinutes = 45
    @State private var newProfileMessage = ""
    @State private var newProfileStartHour = 9
    @State private var newProfileEndHour = 18
    @State private var newProfileCategoryIDs = Set([ActivityCategory.work.id])
    @State private var newProfileWeekdays = Set([2, 3, 4, 5, 6])
    @State private var newProfileBlockedApplications: [String] = []
    @State private var newProfileBlockedDomains: [String] = []

    private var goalProgress: [GoalProgress] {
        store.goalProgress(for: selectedDay)
    }

    private var focusInsights: [FocusProfileInsight] {
        store.focusProfileInsights()
    }

    private var shieldInsights: [FocusProfileInsight] {
        focusInsights.filter { $0.profile.hasBlockingRules }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Foco",
                    title: "Metas, foco e anti-distracao",
                    subtitle: "Configure limites, janelas de foco e metas por categoria para o luum ajudar voce a manter o dia alinhado com a sua intencao."
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 18)], spacing: 18) {
                    focusStatusCard
                    focusShieldCard
                }
                goalsCard
                newGoalCard
                profilesCard
                newProfileCard
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .onAppear(perform: syncDrafts)
    }

    private var focusStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pulso do momento")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                CompactStatPill(
                    title: "\(focusInsights.filter(\.isTriggered).count)",
                    detail: "alertas"
                )
            }

            if let focusModeStatusMessage = store.focusModeStatusMessage {
                Text(focusModeStatusMessage)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Nenhum perfil disparou agora. O luum continua acompanhando as categorias ativas.")
                    .foregroundStyle(LuumTheme.textSecondary)
            }

            VStack(spacing: 10) {
                ForEach(focusInsights.prefix(4)) { insight in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(insight.profile.kind == .focus ? LuumTheme.electricBlue : LuumTheme.hotPink)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.profile.title)
                                .foregroundStyle(.white)
                                .font(.subheadline.weight(.semibold))

                            Text(insight.messageSubtitle)
                                .foregroundStyle(LuumTheme.textSecondary)
                                .font(.caption)
                        }

                        Spacer()

                        Text(insight.isTriggered ? "Ativo" : "Monitorando")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(insight.isTriggered ? LuumTheme.hotPink : LuumTheme.textMuted)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(0.03))
                    )
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 30)
    }

    private var focusShieldCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Escudo de foco")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                CompactStatPill(
                    title: "\(store.focusShieldProfilesCount)",
                    detail: "escudos"
                )
            }

            if let match = store.currentFocusBlockMatch {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Bloqueio ativo agora", systemImage: "hand.raised.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LuumTheme.hotPink)

                    Text(match.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(match.detail)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LuumTheme.hotPink.opacity(0.08))
                )
            } else if let focusShieldStatusMessage = store.focusShieldStatusMessage {
                Text(focusShieldStatusMessage)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Adicione apps e sites dentro dos perfis para o luum reagir na hora quando alguma distracao entrar em cena.")
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if shieldInsights.isEmpty {
                Text("Nenhum perfil com bloqueio configurado ainda.")
                    .foregroundStyle(LuumTheme.textMuted)
                    .font(.caption)
            } else {
                VStack(spacing: 10) {
                    ForEach(shieldInsights.prefix(4)) { insight in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(insight.isWithinSchedule ? LuumTheme.electricBlue : LuumTheme.textMuted)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight.profile.title)
                                    .foregroundStyle(.white)
                                    .font(.subheadline.weight(.semibold))

                                Text("\(insight.blockedTargetCount) bloqueio(s) • \(insight.isWithinSchedule ? "janela ativa" : "fora da janela")")
                                    .foregroundStyle(LuumTheme.textSecondary)
                                    .font(.caption)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.white.opacity(0.03))
                        )
                    }
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12), cornerRadius: 30)
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Metas ativas")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if goalProgress.isEmpty {
                Text("Nenhuma meta ativa para a data selecionada.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                ForEach(goalProgress) { progress in
                    EditableGoalRow(store: store, progress: progress)
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12), cornerRadius: 30)
    }

    private var newGoalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nova meta")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            TextField("Titulo da meta", text: $newGoalTitle)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Picker("Categoria", selection: $newGoalCategoryID) {
                    ForEach(store.categories) { category in
                        Text(category.title).tag(category.id)
                    }
                }
                .pickerStyle(.menu)

                Picker("Periodo", selection: $newGoalPeriod) {
                    ForEach(GoalPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                Picker("Direcao", selection: $newGoalDirection) {
                    ForEach(GoalDirection.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .pickerStyle(.segmented)

                DurationEditor(
                    title: "Meta",
                    totalMinutes: $newGoalTargetMinutes,
                    range: 5 ... 600
                )
            }

            Button("Adicionar meta") {
                store.addUsageGoal(
                    title: newGoalTitle,
                    categoryID: newGoalCategoryID,
                    targetMinutes: newGoalTargetMinutes,
                    period: newGoalPeriod,
                    direction: newGoalDirection
                )
                newGoalTitle = ""
            }
            .buttonStyle(.glassProminent)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12), cornerRadius: 30)
    }

    private var profilesCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Perfis de foco")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if store.focusProfiles.isEmpty {
                Text("Nenhum perfil configurado ainda.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                ForEach(store.focusProfiles) { profile in
                    EditableFocusProfileCard(store: store, profile: profile)
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12), cornerRadius: 30)
    }

    private var newProfileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Novo perfil")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            TextField("Nome do perfil", text: $newProfileTitle)
                .textFieldStyle(.roundedBorder)

            Picker("Modo", selection: $newProfileKind) {
                ForEach(FocusModeKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            CategoryMultiSelector(categories: store.categories, selectedCategoryIDs: $newProfileCategoryIDs)

            HStack(spacing: 12) {
                DurationEditor(
                    title: "Limite",
                    totalMinutes: $newProfileThresholdMinutes,
                    range: 5 ... 240
                )

                Stepper(value: $newProfileStartHour, in: 0 ... 23, step: 1) {
                    Text("Inicio \(newProfileStartHour)h")
                        .foregroundStyle(.white)
                }

                Stepper(value: $newProfileEndHour, in: 1 ... 24, step: 1) {
                    Text("Fim \(newProfileEndHour)h")
                        .foregroundStyle(.white)
                }
            }

            TextField("Mensagem do perfil", text: $newProfileMessage, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            FocusBlockRuleEditor(
                blockedApplications: $newProfileBlockedApplications,
                blockedDomains: $newProfileBlockedDomains
            )

            WeekdaySelector(selectedWeekdays: $newProfileWeekdays)

            Button("Adicionar perfil") {
                store.addFocusProfile(
                    title: newProfileTitle,
                    kind: newProfileKind,
                    categoryIDs: Array(newProfileCategoryIDs),
                    thresholdMinutes: newProfileThresholdMinutes,
                    weekdays: Array(newProfileWeekdays).sorted(),
                    startHour: newProfileStartHour,
                    endHour: newProfileEndHour,
                    message: newProfileMessage,
                    blockedApplications: newProfileBlockedApplications,
                    blockedDomains: newProfileBlockedDomains
                )

                newProfileTitle = ""
                newProfileMessage = ""
                newProfileBlockedApplications = []
                newProfileBlockedDomains = []
            }
            .buttonStyle(.glassProminent)
            .disabled(newProfileCategoryIDs.isEmpty || newProfileWeekdays.isEmpty)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 30)
    }

    private func syncDrafts() {
        if store.category(for: newGoalCategoryID) == nil {
            newGoalCategoryID = store.defaultCategoryID
        }

        newProfileCategoryIDs = Set(newProfileCategoryIDs.filter { store.category(for: $0) != nil })
        if newProfileCategoryIDs.isEmpty {
            newProfileCategoryIDs = [store.defaultCategoryID]
        }
    }
}

private struct EditableGoalRow: View {
    @Bindable var store: ActivityStore
    let progress: GoalProgress

    @State private var title: String
    @State private var categoryID: String
    @State private var targetMinutes: Int
    @State private var period: GoalPeriod
    @State private var direction: GoalDirection
    @State private var isEnabled: Bool

    init(store: ActivityStore, progress: GoalProgress) {
        self.store = store
        self.progress = progress
        _title = State(initialValue: progress.goal.title)
        _categoryID = State(initialValue: progress.goal.categoryID)
        _targetMinutes = State(initialValue: progress.goal.targetMinutes)
        _period = State(initialValue: progress.goal.period)
        _direction = State(initialValue: progress.goal.direction)
        _isEnabled = State(initialValue: progress.goal.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(progress.category.title) • \(LuumFormatters.duration(progress.currentDuration)) de \(formattedGoalDuration(progress.goal.targetMinutes))")
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textSecondary)
                }

                Spacer()

                Text(progress.isMet ? "No alvo" : "Ajustar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progress.isMet ? LuumTheme.electricBlue : LuumTheme.hotPink)
            }

            ProgressView(value: min(progress.progress, 1.2))
                .tint(progress.isMet ? LuumTheme.electricBlue : LuumTheme.hotPink)

            HStack(spacing: 10) {
                TextField("Titulo", text: $title)
                    .textFieldStyle(.roundedBorder)

                Picker("Categoria", selection: $categoryID) {
                    ForEach(store.categories) { category in
                        Text(category.title).tag(category.id)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 10) {
                Picker("Periodo", selection: $period) {
                    ForEach(GoalPeriod.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Direcao", selection: $direction) {
                    ForEach(GoalDirection.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                DurationEditor(
                    title: "Meta",
                    totalMinutes: $targetMinutes,
                    range: 5 ... 600
                )

                Toggle("Ativa", isOn: $isEnabled)
                    .toggleStyle(.switch)
            }

            HStack(spacing: 10) {
                Button("Salvar") {
                    store.updateUsageGoal(
                        UsageGoal(
                            id: progress.goal.id,
                            title: title,
                            categoryID: categoryID,
                            targetMinutes: targetMinutes,
                            period: period,
                            direction: direction,
                            isEnabled: isEnabled
                        )
                    )
                }
                .buttonStyle(.glassProminent)

                Button("Remover", role: .destructive) {
                    store.removeUsageGoal(id: progress.goal.id)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.03))
        )
    }
}

private struct EditableFocusProfileCard: View {
    @Bindable var store: ActivityStore
    let profile: FocusModeProfile

    @State private var title: String
    @State private var kind: FocusModeKind
    @State private var thresholdMinutes: Int
    @State private var message: String
    @State private var startHour: Int
    @State private var endHour: Int
    @State private var isEnabled: Bool
    @State private var categoryIDs: Set<String>
    @State private var weekdays: Set<Int>
    @State private var blockedApplications: [String]
    @State private var blockedDomains: [String]

    init(store: ActivityStore, profile: FocusModeProfile) {
        self.store = store
        self.profile = profile
        _title = State(initialValue: profile.title)
        _kind = State(initialValue: profile.kind)
        _thresholdMinutes = State(initialValue: profile.thresholdMinutes)
        _message = State(initialValue: profile.message)
        _startHour = State(initialValue: profile.startHour)
        _endHour = State(initialValue: profile.endHour)
        _isEnabled = State(initialValue: profile.isEnabled)
        _categoryIDs = State(initialValue: Set(profile.categoryIDs))
        _weekdays = State(initialValue: Set(profile.weekdays))
        _blockedApplications = State(initialValue: profile.blockedApplications)
        _blockedDomains = State(initialValue: profile.blockedDomains)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Toggle("Ativo", isOn: $isEnabled)
                    .toggleStyle(.switch)
            }

            Picker("Modo", selection: $kind) {
                ForEach(FocusModeKind.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            CategoryMultiSelector(categories: store.categories, selectedCategoryIDs: $categoryIDs)
            WeekdaySelector(selectedWeekdays: $weekdays)

            HStack(spacing: 12) {
                DurationEditor(
                    title: "Limite",
                    totalMinutes: $thresholdMinutes,
                    range: 5 ... 240
                )

                Stepper(value: $startHour, in: 0 ... 23, step: 1) {
                    Text("Inicio \(startHour)h")
                        .foregroundStyle(.white)
                }

                Stepper(value: $endHour, in: 1 ... 24, step: 1) {
                    Text("Fim \(endHour)h")
                        .foregroundStyle(.white)
                }
            }

            TextField("Mensagem", text: $message, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            FocusBlockRuleEditor(
                blockedApplications: $blockedApplications,
                blockedDomains: $blockedDomains
            )

            HStack(spacing: 10) {
                Button("Salvar") {
                    store.updateFocusProfile(
                        FocusModeProfile(
                            id: profile.id,
                            title: title,
                            kind: kind,
                            categoryIDs: Array(categoryIDs),
                            thresholdMinutes: thresholdMinutes,
                            weekdays: Array(weekdays).sorted(),
                            startHour: startHour,
                            endHour: endHour,
                            isEnabled: isEnabled,
                            message: message,
                            blockedApplications: blockedApplications,
                            blockedDomains: blockedDomains
                        )
                    )
                }
                .buttonStyle(.glassProminent)

                Button("Remover", role: .destructive) {
                    store.removeFocusProfile(id: profile.id)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.03))
        )
    }
}

private struct DurationEditor: View {
    let title: String
    @Binding var totalMinutes: Int
    let range: ClosedRange<Int>

    private let minuteStep = 5

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { totalMinutes / 60 },
            set: { newHours in
                totalMinutes = clampedTotal(hours: newHours, minutes: minuteComponent)
            }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { minuteComponent },
            set: { newMinutes in
                totalMinutes = clampedTotal(hours: hoursBinding.wrappedValue, minutes: newMinutes)
            }
        )
    }

    private var maxHours: Int {
        range.upperBound / 60
    }

    private var minuteComponent: Int {
        let component = max(0, totalMinutes % 60)
        return (component / minuteStep) * minuteStep
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LuumTheme.textMuted)

            Text(formattedGoalDuration(totalMinutes))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                Stepper(value: hoursBinding, in: 0 ... maxHours, step: 1) {
                    Text("\(hoursBinding.wrappedValue)h")
                        .foregroundStyle(.white)
                }

                Stepper(value: minutesBinding, in: 0 ... 55, step: minuteStep) {
                    Text("\(minutesBinding.wrappedValue)m")
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.03))
        )
    }

    private func clampedTotal(hours: Int, minutes: Int) -> Int {
        let normalizedMinutes = min(55, max(0, (minutes / minuteStep) * minuteStep))
        let combined = (hours * 60) + normalizedMinutes
        return min(max(range.lowerBound, combined), range.upperBound)
    }
}

private func formattedGoalDuration(_ totalMinutes: Int) -> String {
    LuumFormatters.duration(TimeInterval(totalMinutes * 60))
}

private struct FocusBlockRuleEditor: View {
    @Binding var blockedApplications: [String]
    @Binding var blockedDomains: [String]

    @State private var applicationInput = ""
    @State private var domainInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Escudo anti-distracao")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Quando este perfil estiver dentro da janela, o luum avisa imediatamente se algum app ou site bloqueado ganhar foco.")
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                TextField("Bloquear app: Slack, Steam, YouTube Music", text: $applicationInput)
                    .textFieldStyle(.roundedBorder)

                Button("Adicionar") {
                    addApplication()
                }
                .buttonStyle(.glassProminent)
                .disabled(normalized(applicationInput).isEmpty)
            }

            FocusTagList(items: blockedApplications, tint: LuumTheme.hotPink) { item in
                blockedApplications.removeAll { $0 == item }
            }

            HStack(spacing: 12) {
                TextField("Bloquear site: youtube.com, reddit.com", text: $domainInput)
                    .textFieldStyle(.roundedBorder)

                Button("Adicionar") {
                    addDomain()
                }
                .buttonStyle(.glassProminent)
                .disabled(normalized(domainInput).isEmpty)
            }

            FocusTagList(items: blockedDomains, tint: LuumTheme.electricBlue) { item in
                blockedDomains.removeAll { $0 == item }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.025))
        )
    }

    private func addApplication() {
        let cleaned = normalized(applicationInput)
        guard !cleaned.isEmpty else { return }
        if !blockedApplications.contains(cleaned) {
            blockedApplications.append(cleaned)
            blockedApplications.sort()
        }
        applicationInput = ""
    }

    private func addDomain() {
        let cleaned = normalizedDomain(domainInput)
        guard !cleaned.isEmpty else { return }
        if !blockedDomains.contains(cleaned) {
            blockedDomains.append(cleaned)
            blockedDomains.sort()
        }
        domainInput = ""
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedDomain(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let components = URLComponents(string: trimmed), let host = components.host?.lowercased() {
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }

        let lowered = trimmed.lowercased()
        return lowered.hasPrefix("www.") ? String(lowered.dropFirst(4)) : lowered
    }
}

private struct FocusTagList: View {
    let items: [String]
    let tint: Color
    let onRemove: (String) -> Void

    var body: some View {
        if items.isEmpty {
            Text("Nenhum bloqueio configurado.")
                .font(.caption)
                .foregroundStyle(LuumTheme.textMuted)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Text(item)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Button {
                            onRemove(item)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tint.opacity(0.18))
                    )
                }
            }
        }
    }
}

private struct CategoryMultiSelector: View {
    let categories: [ActivityCategory]
    @Binding var selectedCategoryIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Categorias")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(categories) { category in
                    Button {
                        if selectedCategoryIDs.contains(category.id) {
                            selectedCategoryIDs.remove(category.id)
                        } else {
                            selectedCategoryIDs.insert(category.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: category.systemImage)
                            Text(category.title)
                                .lineLimit(1)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selectedCategoryIDs.contains(category.id) ? category.tint.opacity(0.26) : .white.opacity(0.03))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
