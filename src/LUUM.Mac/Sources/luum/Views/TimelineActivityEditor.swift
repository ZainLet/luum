import SwiftUI

struct TimelineActivityEditor: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var store: ActivityStore
    let activity: ResolvedActivitySample

    @State private var selectedCategoryID: String
    @State private var note: String
    @State private var splitDate: Date

    private var canSplit: Bool {
        activity.duration >= 120
    }

    private var splitRange: ClosedRange<Date> {
        let lowerBound = activity.startDate.addingTimeInterval(60)
        let upperBound = max(lowerBound, activity.endDate.addingTimeInterval(-60))
        return lowerBound ... upperBound
    }

    init(store: ActivityStore, activity: ResolvedActivitySample) {
        self.store = store
        self.activity = activity
        _selectedCategoryID = State(initialValue: activity.category.id)
        _note = State(initialValue: activity.note ?? "")
        _splitDate = State(initialValue: activity.startDate.addingTimeInterval(max(activity.duration / 2, 60)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                categoryCard
                noteCard
                splitCard
                mergeCard
                actionCard
            }
            .padding(24)
        }
        .frame(width: 620, height: 760)
        .background(LuumTheme.pageGradient.opacity(0.7))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activity.pageTitle ?? activity.applicationName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text(activity.webDomain ?? activity.applicationName)
                .foregroundStyle(LuumTheme.textSecondary)

            Text(LuumFormatters.timeRange(start: activity.startDate, end: activity.endDate))
                .font(.caption.weight(.semibold))
                .foregroundStyle(LuumTheme.electricBlue)
        }
        .padding(20)
        .luumGlassCard(tint: activity.category.tint.opacity(0.14), cornerRadius: 28)
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Categoria")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Picker("Categoria", selection: $selectedCategoryID) {
                ForEach(store.categories) { category in
                    Text(category.title).tag(category.id)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 10) {
                Button("Salvar categoria") {
                    store.overrideActivityCategory(sampleID: activity.id, categoryID: selectedCategoryID)
                }
                .buttonStyle(.glassProminent)

                if let domain = activity.webDomain {
                    Button("Aprender site") {
                        store.assignCategory(toDomain: domain, categoryID: selectedCategoryID)
                    }
                    .buttonStyle(.bordered)
                }

                Button("Aprender app") {
                    store.assignCategory(toApplication: activity.applicationName, categoryID: selectedCategoryID)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12), cornerRadius: 28)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nota")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            TextField("Observacao manual sobre esse bloco", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button("Salvar nota") {
                store.updateActivityNote(sampleID: activity.id, note: note)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(20)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12), cornerRadius: 28)
    }

    private var splitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dividir bloco")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if canSplit {
                DatePicker("Momento da divisao", selection: $splitDate, in: splitRange, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
            } else {
                Text("Esse bloco ainda esta curto demais para ser dividido com seguranca.")
                    .foregroundStyle(LuumTheme.textSecondary)
            }

            HStack(spacing: 10) {
                Button("Dividir no meio") {
                    splitDate = activity.startDate.addingTimeInterval(max(activity.duration / 2, 60))
                    store.splitActivity(sampleID: activity.id, at: splitDate)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(!canSplit)

                Button("Aplicar divisao") {
                    store.splitActivity(sampleID: activity.id, at: splitDate)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .disabled(!canSplit)
            }
        }
        .padding(20)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12), cornerRadius: 28)
    }

    private var mergeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Juntar blocos")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                Button("Juntar com anterior") {
                    store.mergeActivity(sampleID: activity.id, direction: .previous)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(!store.canMergeActivity(sampleID: activity.id, direction: .previous))

                Button("Juntar com proximo") {
                    store.mergeActivity(sampleID: activity.id, direction: .next)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(!store.canMergeActivity(sampleID: activity.id, direction: .next))
            }
        }
        .padding(20)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.12), cornerRadius: 28)
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Acoes")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                Button(activity.sample.isHidden ? "Voltar a mostrar" : "Ocultar bloco") {
                    store.setActivityHidden(sampleID: activity.id, isHidden: !activity.sample.isHidden)
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Remover ajustes") {
                    store.resetActivityEdits(sampleID: activity.id)
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.1), cornerRadius: 28)
    }
}
