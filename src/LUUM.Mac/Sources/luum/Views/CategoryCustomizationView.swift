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
    let summary: DailySummary

    @State private var newCategoryTitle = ""
    @State private var newCategorySymbol = "tag.fill"
    @State private var newCategoryColor: CategoryColorToken = .violet
    @State private var newRuleCategoryID = ActivityCategory.work.id
    @State private var newRuleTarget: RuleMatchTarget = .domain
    @State private var newRulePattern = ""
    @State private var newIgnoredApplication = ""
    @State private var newIgnoredDomain = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Categorias",
                    title: "Personalize o motor do luum",
                    subtitle: "Crie categorias novas, ajuste cor e icone, distribua apps e sites por regras e bloqueie o que nao deve contaminar a sua leitura."
                )

                categoryBreakdownCard
                categoriesEditorCard
                rulesCard
                blocklistCard
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Categorias ativas hoje")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if summary.categoryBreakdown.isEmpty {
                Text("Ainda nao existem categorias consolidadas para este dia.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(summary.categoryBreakdown) { bucket in
                        HStack {
                            Label(bucket.category.title, systemImage: bucket.category.systemImage)
                                .foregroundStyle(.white)

                            Spacer()

                            Text(LuumFormatters.duration(bucket.duration))
                                .foregroundStyle(bucket.category.tint)
                                .font(.headline)
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
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14))
    }

    private var categoriesEditorCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Editor de categorias")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ForEach(store.categories) { category in
                EditableCategoryCard(store: store, category: category)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Adicionar categoria")
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

                    Button("Adicionar") {
                        store.addCategory(title: newCategoryTitle, systemImage: newCategorySymbol, colorToken: newCategoryColor)
                        newCategoryTitle = ""
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.03))
            )
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12))
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Regras de classificacao")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if store.categoryRules.isEmpty {
                Text("Nenhuma regra configurada ainda.")
                    .foregroundStyle(LuumTheme.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.categoryRules) { rule in
                        HStack(alignment: .top, spacing: 12) {
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
                            }

                            Spacer()

                            Button(role: .destructive) {
                                store.removeRule(id: rule.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white.opacity(0.68))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white.opacity(0.03))
                        )
                    }
                }
            }

            Divider()
                .overlay(.white.opacity(0.08))

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

                    Button("Adicionar") {
                        store.addRule(categoryID: newRuleCategoryID, matchTarget: newRuleTarget, pattern: newRulePattern)
                        newRulePattern = ""
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.electricBlue.opacity(0.12))
    }

    private var blocklistCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Bloqueios de monitoramento")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Use bloqueios para impedir que alguns apps ou sites entrem nas metricas e atrapalhem a leitura real do seu dia.")
                .foregroundStyle(LuumTheme.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Apps ignorados")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    TextField("Ex.: Adobe Premiere, Codex, company.thebrowser.Browser", text: $newIgnoredApplication)
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
                .overlay(.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 10) {
                Text("Sites ignorados")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    TextField("Ex.: youtube.com, google.com", text: $newIgnoredDomain)
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
        .luumGlassCard(tint: ActivityCategory.utilities.glassTint)
    }
}

private struct EditableCategoryCard: View {
    @Bindable var store: ActivityStore
    let category: ActivityCategory

    @State private var title: String
    @State private var symbol: String
    @State private var colorToken: CategoryColorToken

    init(store: ActivityStore, category: ActivityCategory) {
        self.store = store
        self.category = category
        _title = State(initialValue: category.title)
        _symbol = State(initialValue: category.systemImage)
        _colorToken = State(initialValue: category.colorToken)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: category.systemImage)
                    .foregroundStyle(category.tint)
                    .font(.title3)
                    .frame(width: 28)

                Text(category.isBuiltIn ? "Categoria base" : "Categoria customizada")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.64))

                Spacer()

                if !category.isBuiltIn {
                    Button(role: .destructive) {
                        store.removeCategory(id: category.id)
                    } label: {
                        Label("Remover", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.72))
                }
            }

            TextField("Nome", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Picker("Icone", selection: $symbol) {
                    ForEach(categorySymbolOptions, id: \.self) { symbol in
                        Label(symbol, systemImage: symbol).tag(symbol)
                    }
                }
                .pickerStyle(.menu)

                Picker("Cor", selection: $colorToken) {
                    ForEach(CategoryColorToken.allCases) { colorToken in
                        Text(colorToken.title).tag(colorToken)
                    }
                }
                .pickerStyle(.menu)

                Button("Salvar") {
                    store.updateCategoryTitle(id: category.id, title: title)
                    store.updateCategorySymbol(id: category.id, systemImage: symbol)
                    store.updateCategoryColor(id: category.id, colorToken: colorToken)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.03))
        )
    }
}

private struct FlowTagList: View {
    let items: [String]
    let tint: Color
    let onRemove: (String) -> Void

    var body: some View {
        if items.isEmpty {
            Text("Nenhum item bloqueado ainda.")
                .foregroundStyle(LuumTheme.textSecondary)
                .font(.caption)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Text(item)
                            .foregroundStyle(.white)
                            .font(.caption.weight(.medium))

                        Spacer()

                        Button(role: .destructive) {
                            onRemove(item)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.72))
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
