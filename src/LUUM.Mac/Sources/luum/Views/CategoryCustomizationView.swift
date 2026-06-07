import SwiftUI

private let categorySymbolOptions = [
    "briefcase.fill",
    "play.tv.fill",
    "bubble.left.and.bubble.right.fill",
    "book.closed.fill",
    "slider.horizontal.3",
    "tag.fill",
    "megaphone.fill",
    "chart.bar.fill",
    "paintpalette.fill",
    "gamecontroller.fill",
    "heart.fill",
    "moon.stars.fill",
]

struct CategoryCustomizationView: View {
    @Bindable var store: ActivityStore
    let selectedDay: Date

    @State private var newCategoryTitle = ""
    @State private var newCategorySymbol = "tag.fill"
    @State private var newCategoryColor: CategoryColorToken = .violet
    @State private var newRuleCategoryID = ActivityCategory.work.id
    @State private var newRuleTarget: RuleMatchTarget = .domain
    @State private var newRulePattern = ""
    @State private var newIgnoredApplication = ""
    @State private var newIgnoredDomain = ""
    @State private var showsAdvancedRules = false

    private var categoryIDs: [String] {
        store.categories.map(\.id)
    }

    private var summary: DailySummary {
        _ = store.summaryRevision
        return store.summary(for: selectedDay)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LuumSectionHeader(
                    eyebrow: "Categorias",
                    title: "Personalize o motor do luum",
                    subtitle: "Use Apps e Sites para reclassificar o dia a dia rapidamente. Aqui ficam o editor de categorias, os bloqueios e as regras avancadas."
                )

                todayOverviewCard
                suggestionsCard
                categoriesEditorCard
                advancedRulesCard
                blocklistCard
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .onAppear(perform: syncSelections)
        .onChange(of: categoryIDs) { _, _ in
            syncSelections()
        }
        .onChange(of: selectedDay) { _, _ in
            syncSelections()
        }
    }

    private var todayOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Leitura do dia")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("O ajuste rapido agora mora nas abas Apps e Sites. Nesta tela voce mantem o sistema organizado sem abrir um painel gigante de itens.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(store.categories.count)",
                    detail: "categorias"
                )
            }

            if summary.categoryBreakdown.isEmpty {
                Text("Ainda nao existem categorias consolidadas para este dia.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(summary.categoryBreakdown.prefix(4)) { bucket in
                        HStack(spacing: 12) {
                            Image(systemName: bucket.category.systemImage)
                                .foregroundStyle(bucket.category.tint)
                                .frame(width: 18)

                            Text(bucket.category.title)
                                .foregroundStyle(.white)

                            Spacer()

                            Text(LuumFormatters.duration(bucket.duration))
                                .foregroundStyle(bucket.category.tint)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.white.opacity(0.02))
                        )
                    }
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12), cornerRadius: 30, shadowOpacity: 0.1)
    }

    private var categoriesEditorCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Editor de categorias")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                ForEach(store.categories) { category in
                    EditableCategoryCard(store: store, category: category)
                }
            }

            Divider()
                .overlay(.white.opacity(0.06))

            VStack(alignment: .leading, spacing: 14) {
                Text("Nova categoria")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField("Nome da categoria", text: $newCategoryTitle)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Picker("Icone", selection: $newCategorySymbol) {
                        ForEach(categorySymbolOptions, id: \.self) { symbol in
                            Label(symbol, systemImage: symbol).tag(symbol)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Cor", selection: $newCategoryColor) {
                        ForEach(CategoryColorToken.allCases) { colorToken in
                            Text(colorToken.title).tag(colorToken)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()

                    Button("Adicionar") {
                        store.addCategory(
                            title: newCategoryTitle,
                            systemImage: newCategorySymbol,
                            colorToken: newCategoryColor
                        )
                        newCategoryTitle = ""
                        newCategorySymbol = "tag.fill"
                        newCategoryColor = .violet
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.1), cornerRadius: 30, shadowOpacity: 0.1)
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sugestoes inteligentes")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Quando voce corrige a mesma classificacao mais de uma vez, o luum sugere transformar isso em regra permanente.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(store.classificationSuggestions.count)",
                    detail: "sugestoes"
                )
            }

            if store.classificationSuggestions.isEmpty {
                Text("Ainda nao ha sugestoes. Assim que voce fizer algumas correcoes manuais repetidas, o luum vai sugerir as regras por voce.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.classificationSuggestions.prefix(6)) { suggestion in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.pattern)
                                    .foregroundStyle(.white)
                                    .font(.subheadline.weight(.semibold))

                                Text("\(suggestion.reason) \(suggestion.sampleCount)x • \(LuumFormatters.duration(suggestion.totalDuration))")
                                    .foregroundStyle(LuumTheme.textSecondary)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Label(suggestion.recommendedCategory.title, systemImage: suggestion.recommendedCategory.systemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(suggestion.recommendedCategory.tint)

                            Button("Aplicar") {
                                store.applySuggestion(suggestion)
                            }
                            .buttonStyle(.glassProminent)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white.opacity(0.03))
                        )
                    }
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.1), cornerRadius: 30, shadowOpacity: 0.1)
    }

    private var advancedRulesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Regras avancadas")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Se voce quiser um mapeamento mais permanente, pode criar regras por app, bundle ou dominio. Novas regras entram no topo para sobrescrever classificacoes anteriores.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompactStatPill(
                    title: "\(store.categoryRules.count)",
                    detail: "regras"
                )
            }

            DisclosureGroup(isExpanded: $showsAdvancedRules) {
                VStack(alignment: .leading, spacing: 14) {
                    if store.categoryRules.isEmpty {
                        Text("Nenhuma regra salva.")
                            .foregroundStyle(LuumTheme.textSecondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.categoryRules) { rule in
                                RuleRow(store: store, rule: rule)
                            }
                        }
                    }

                    Divider()
                        .overlay(.white.opacity(0.06))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nova regra")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            Picker("Categoria", selection: $newRuleCategoryID) {
                                ForEach(store.categories) { category in
                                    Text(category.title).tag(category.id)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Tipo", selection: $newRuleTarget) {
                                ForEach(RuleMatchTarget.allCases) { target in
                                    Text(target.title).tag(target)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        HStack(spacing: 12) {
                            TextField("Ex.: figma.com, Cursor, com.apple.Safari", text: $newRulePattern)
                                .textFieldStyle(.roundedBorder)

                            Button("Salvar regra") {
                                store.addRule(
                                    categoryID: resolvedRuleCategoryID,
                                    matchTarget: newRuleTarget,
                                    pattern: newRulePattern
                                )
                                newRulePattern = ""
                            }
                            .buttonStyle(.glassProminent)
                            .disabled(newRulePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(.top, 14)
            } label: {
                Text("Mostrar regras salvas")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.1), cornerRadius: 30, shadowOpacity: 0.1)
    }

    private var blocklistCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Bloqueios de monitoramento")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Use bloqueios para tirar da leitura qualquer app ou site que esteja poluindo seu historico.")
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                Text("Apps ignorados")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    TextField("Ex.: Adobe Premiere, Codex", text: $newIgnoredApplication)
                        .textFieldStyle(.roundedBorder)

                    Button("Ignorar app") {
                        store.addIgnoredApplication(newIgnoredApplication)
                        newIgnoredApplication = ""
                    }
                    .buttonStyle(.glassProminent)
                }

                FlowTagList(items: store.ignoredApplications, tint: LuumTheme.hotPink) { item in
                    store.removeIgnoredApplication(item)
                }
            }

            Divider()
                .overlay(.white.opacity(0.06))

            VStack(alignment: .leading, spacing: 12) {
                Text("Sites ignorados")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    TextField("Ex.: youtube.com, reddit.com", text: $newIgnoredDomain)
                        .textFieldStyle(.roundedBorder)

                    Button("Ignorar site") {
                        store.addIgnoredDomain(newIgnoredDomain)
                        newIgnoredDomain = ""
                    }
                    .buttonStyle(.glassProminent)
                }

                FlowTagList(items: store.ignoredDomains, tint: LuumTheme.electricBlue) { item in
                    store.removeIgnoredDomain(item)
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.hotPink.opacity(0.08), cornerRadius: 30, shadowOpacity: 0.1)
    }

    private var resolvedRuleCategoryID: String {
        store.category(for: newRuleCategoryID) != nil ? newRuleCategoryID : store.defaultCategoryID
    }

    private func syncSelections() {
        if store.category(for: newRuleCategoryID) == nil {
            newRuleCategoryID = store.defaultCategoryID
        }
    }
}

private struct EditableCategoryCard: View {
    @Bindable var store: ActivityStore
    let category: ActivityCategory

    @State private var title: String
    @State private var systemImage: String
    @State private var colorToken: CategoryColorToken

    init(store: ActivityStore, category: ActivityCategory) {
        self.store = store
        self.category = category
        _title = State(initialValue: category.title)
        _systemImage = State(initialValue: category.systemImage)
        _colorToken = State(initialValue: category.colorToken)
    }

    private var previewTint: Color {
        ActivityCategory(
            id: category.id,
            title: category.title,
            systemImage: systemImage,
            colorToken: colorToken,
            isBuiltIn: category.isBuiltIn
        ).tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(previewTint)
                    .frame(width: 18)

                TextField("Nome", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .disabled(category.isBuiltIn)

                Spacer()

                if !category.isBuiltIn {
                    Button(role: .destructive) {
                        store.removeCategory(id: category.id)
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(spacing: 12) {
                Picker("Icone", selection: $systemImage) {
                    ForEach(categorySymbolOptions, id: \.self) { symbol in
                        Label(symbol, systemImage: symbol).tag(symbol)
                    }
                }
                .pickerStyle(.menu)

                Picker("Cor", selection: $colorToken) {
                    ForEach(CategoryColorToken.allCases) { token in
                        Text(token.title).tag(token)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Button("Salvar") {
                    store.updateCategoryTitle(id: category.id, title: title)
                    store.updateCategorySymbol(id: category.id, systemImage: systemImage)
                    store.updateCategoryColor(id: category.id, colorToken: colorToken)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.02))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.05))
        }
        .onAppear(perform: syncDrafts)
        .onChange(of: category.title) { _, _ in
            syncDrafts()
        }
        .onChange(of: category.systemImage) { _, _ in
            syncDrafts()
        }
        .onChange(of: category.colorToken) { _, _ in
            syncDrafts()
        }
    }

    private func syncDrafts() {
        title = category.title
        systemImage = category.systemImage
        colorToken = category.colorToken
    }
}

private struct RuleRow: View {
    @Bindable var store: ActivityStore
    let rule: CategoryRule

    var body: some View {
        HStack(spacing: 12) {
            if let category = store.category(for: rule.categoryID) {
                Image(systemName: category.systemImage)
                    .foregroundStyle(category.tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title)
                        .foregroundStyle(.white)
                        .font(.headline)

                    Text("\(rule.matchTarget.title): \(rule.pattern)")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .font(.caption)
                }
            } else {
                Text(rule.pattern)
                    .foregroundStyle(.white)
            }

            Spacer()

            Button(role: .destructive) {
                store.removeRule(id: rule.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.02))
        )
    }
}

private struct FlowTagList: View {
    let items: [String]
    let tint: Color
    let onRemove: (String) -> Void

    var body: some View {
        if items.isEmpty {
            Text("Nenhum item bloqueado.")
                .foregroundStyle(LuumTheme.textSecondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 10) {
                        Text(item)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer(minLength: 8)

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
