import SwiftUI

struct RemindersView: View {
    @Bindable var store: ActivityStore

    @State private var newReminderTitle = ""
    @State private var newReminderCategoryID = ActivityCategory.work.id
    @State private var newReminderThreshold = 60
    @State private var newReminderMessage = ""
    @State private var selectedWeekdays = Set([2, 3, 4, 5, 6])

    private var categoryIDs: [String] {
        store.categories.map(\.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Lembretes",
                    title: "Pausas e alertas de distracao",
                    subtitle: "Configure quanto tempo você pode ficar em uma mesma categoria antes do luum avisar. Isso funciona tanto para trabalho intenso quanto para entretenimento."
                )

                notificationsCard
                remindersListCard
                newReminderCard
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .onAppear(perform: syncSelections)
        .onChange(of: categoryIDs) { _, _ in
            syncSelections()
        }
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notificações")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(store.notificationsAuthorized
                 ? "As notificações do luum estão liberadas para lembretes locais."
                 : (store.notificationPermissionMessage ?? "Ative as notificações para receber alertas locais do luum."))
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let lastReminderStatusMessage = store.lastReminderStatusMessage {
                Text(lastReminderStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Button(store.notificationsAuthorized ? "Atualizar permissão" : "Permitir notificações") {
                store.requestNotificationAuthorization()
            }
            .buttonStyle(.glassProminent)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12))
    }

    private var remindersListCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Regras ativas")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if store.reminderProfiles.isEmpty {
                Text("Nenhum lembrete configurado ainda.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                ForEach(store.reminderProfiles) { reminder in
                    EditableReminderCard(store: store, reminder: reminder)
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.16))
    }

    private var newReminderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Novo lembrete")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            TextField("Titulo do lembrete", text: $newReminderTitle)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Picker("Categoria", selection: $newReminderCategoryID) {
                    ForEach(store.categories) { category in
                        Text(category.title).tag(category.id)
                    }
                }
                .pickerStyle(.menu)

                Stepper(value: $newReminderThreshold, in: 5 ... 240, step: 5) {
                    Text("\(newReminderThreshold) minutos")
                        .foregroundStyle(.white)
                }
            }

            TextField("Mensagem do lembrete", text: $newReminderMessage, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            WeekdaySelector(selectedWeekdays: $selectedWeekdays)

            Button("Adicionar lembrete") {
                store.addReminder(
                    title: newReminderTitle,
                    categoryID: resolvedNewReminderCategoryID,
                    thresholdMinutes: newReminderThreshold,
                    weekdays: Array(selectedWeekdays).sorted(),
                    message: newReminderMessage
                )

                newReminderTitle = ""
                newReminderMessage = ""
            }
            .buttonStyle(.glassProminent)
            .disabled(newReminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedWeekdays.isEmpty)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12))
    }

    private var resolvedNewReminderCategoryID: String {
        store.category(for: newReminderCategoryID) != nil ? newReminderCategoryID : store.defaultCategoryID
    }

    private func syncSelections() {
        if store.category(for: newReminderCategoryID) == nil {
            newReminderCategoryID = store.defaultCategoryID
        }
    }
}

private struct EditableReminderCard: View {
    @Bindable var store: ActivityStore
    let reminder: ReminderProfile

    @State private var title: String
    @State private var categoryID: String
    @State private var thresholdMinutes: Int
    @State private var message: String
    @State private var isEnabled: Bool
    @State private var selectedWeekdays: Set<Int>

    init(store: ActivityStore, reminder: ReminderProfile) {
        self.store = store
        self.reminder = reminder
        _title = State(initialValue: reminder.title)
        _categoryID = State(initialValue: reminder.categoryID)
        _thresholdMinutes = State(initialValue: reminder.thresholdMinutes)
        _message = State(initialValue: reminder.message)
        _isEnabled = State(initialValue: reminder.isEnabled)
        _selectedWeekdays = State(initialValue: Set(reminder.weekdays))
    }

    private var resolvedCategoryID: String {
        store.category(for: categoryID) != nil ? categoryID : store.defaultCategoryID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Toggle(isOn: $isEnabled) {
                    Text(title.isEmpty ? "Lembrete" : title)
                        .foregroundStyle(.white)
                        .font(.headline)
                }
                .toggleStyle(.switch)

                Spacer()

                Button(role: .destructive) {
                    store.removeReminder(id: reminder.id)
                } label: {
                    Label("Remover", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.72))
            }

            TextField("Titulo", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Picker("Categoria", selection: $categoryID) {
                    ForEach(store.categories) { category in
                        Text(category.title).tag(category.id)
                    }
                }
                .pickerStyle(.menu)

                Stepper(value: $thresholdMinutes, in: 5 ... 240, step: 5) {
                    Text("\(thresholdMinutes) minutos")
                        .foregroundStyle(.white)
                }
            }

            TextField("Mensagem", text: $message, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            WeekdaySelector(selectedWeekdays: $selectedWeekdays)

            Button("Salvar lembrete") {
                store.updateReminder(
                    ReminderProfile(
                        id: reminder.id,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? reminder.title : title,
                        categoryID: resolvedCategoryID,
                        thresholdMinutes: thresholdMinutes,
                        weekdays: Array(selectedWeekdays).sorted(),
                        isEnabled: isEnabled,
                        message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? reminder.message : message
                    )
                )
            }
            .buttonStyle(.glassProminent)
            .disabled(selectedWeekdays.isEmpty)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .onAppear(perform: syncDrafts)
        .onChange(of: reminder.title) { _, _ in
            syncDrafts()
        }
        .onChange(of: reminder.categoryID) { _, _ in
            syncDrafts()
        }
        .onChange(of: reminder.thresholdMinutes) { _, _ in
            syncDrafts()
        }
        .onChange(of: reminder.message) { _, _ in
            syncDrafts()
        }
        .onChange(of: reminder.isEnabled) { _, _ in
            syncDrafts()
        }
        .onChange(of: reminder.weekdays) { _, _ in
            syncDrafts()
        }
        .onChange(of: store.categories.map(\.id)) { _, _ in
            if store.category(for: categoryID) == nil {
                categoryID = store.defaultCategoryID
            }
        }
    }

    private func syncDrafts() {
        title = reminder.title
        categoryID = store.category(for: reminder.categoryID) != nil ? reminder.categoryID : store.defaultCategoryID
        thresholdMinutes = reminder.thresholdMinutes
        message = reminder.message
        isEnabled = reminder.isEnabled
        selectedWeekdays = Set(reminder.weekdays)
    }
}

struct WeekdaySelector: View {
    @Binding var selectedWeekdays: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dias da semana")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 8) {
                ForEach(weekdayItems) { weekday in
                    Button {
                        if selectedWeekdays.contains(weekday.weekday) {
                            selectedWeekdays.remove(weekday.weekday)
                        } else {
                            selectedWeekdays.insert(weekday.weekday)
                        }
                    } label: {
                        Text(weekday.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 34)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedWeekdays.contains(weekday.weekday) ? LuumTheme.accent.opacity(0.28) : .white.opacity(0.03))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weekdayItems: [ReminderWeekday] {
        [
            ReminderWeekday(weekday: 2, label: "Seg"),
            ReminderWeekday(weekday: 3, label: "Ter"),
            ReminderWeekday(weekday: 4, label: "Qua"),
            ReminderWeekday(weekday: 5, label: "Qui"),
            ReminderWeekday(weekday: 6, label: "Sex"),
            ReminderWeekday(weekday: 7, label: "Sab"),
            ReminderWeekday(weekday: 1, label: "Dom"),
        ]
    }
}
