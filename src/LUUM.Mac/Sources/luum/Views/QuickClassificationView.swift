import SwiftUI

enum QuickClassificationKind {
    case applications
    case websites

    var eyebrow: String {
        switch self {
        case .applications:
            "Apps"
        case .websites:
            "Sites"
        }
    }

    var searchPrompt: String {
        switch self {
        case .applications:
            "Buscar app"
        case .websites:
            "Buscar site"
        }
    }

    var helperText: String {
        switch self {
        case .applications:
            "Os apps com mais tempo no dia aparecem primeiro. Voce pode trocar a categoria ou ocultar um item sem abrir uma lista enorme de regras. Se ocultar um navegador, os sites dele continuam aparecendo na aba de sites."
        case .websites:
            "Os dominios mais presentes no dia aparecem primeiro. Ajuste a categoria com um clique ou bloqueie um site para ele sair das metricas."
        }
    }

    var itemCountLabel: String {
        switch self {
        case .applications:
            "apps visiveis"
        case .websites:
            "sites visiveis"
        }
    }

    var ignoreLabel: String {
        switch self {
        case .applications:
            "Ocultar app nas metricas"
        case .websites:
            "Ignorar site"
        }
    }

    @MainActor
    func applyCategory(for item: UsageBreakdownItem, categoryID: String, using store: ActivityStore) {
        switch self {
        case .applications:
            store.assignCategory(toApplication: item.label, categoryID: categoryID)
        case .websites:
            store.assignCategory(toDomain: item.label, categoryID: categoryID)
        }
    }

    @MainActor
    func ignore(_ item: UsageBreakdownItem, using store: ActivityStore) {
        switch self {
        case .applications:
            store.addIgnoredApplication(item.label)
        case .websites:
            store.addIgnoredDomain(item.label)
        }
    }

    @MainActor
    func classifyWithAI(_ item: UsageBreakdownItem, using store: ActivityStore) {
        switch self {
        case .applications:
            store.classifyApplicationWithAI(item)
        case .websites:
            store.classifyDomainWithAI(item)
        }
    }
}

struct QuickClassificationView: View {
    @Bindable var store: ActivityStore
    let kind: QuickClassificationKind
    let title: String
    let subtitle: String
    let emptyState: String
    let selectedDay: Date

    @State private var searchText = ""
    @State private var showsAllItems = false

    private let collapsedItemLimit = 10

    private var items: [UsageBreakdownItem] {
        _ = store.summaryRevision
        let summary = store.summary(for: selectedDay)
        switch kind {
        case .applications:
            return summary.appBreakdown
        case .websites:
            return summary.websiteBreakdown
        }
    }

    private var filteredItems: [UsageBreakdownItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }

        return items.filter { item in
            item.label.localizedCaseInsensitiveContains(query) ||
            (item.secondaryLabel?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var visibleItems: [UsageBreakdownItem] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !showsAllItems else {
            return filteredItems
        }

        return Array(filteredItems.prefix(collapsedItemLimit))
    }

    private var hiddenItemCount: Int {
        max(filteredItems.count - visibleItems.count, 0)
    }

    private var totalVisibleDuration: TimeInterval {
        visibleItems.reduce(0) { partialResult, item in
            partialResult + item.duration
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LuumSectionHeader(eyebrow: kind.eyebrow, title: title, subtitle: subtitle)

                filtersCard

                if items.isEmpty {
                    Text(emptyState)
                        .foregroundStyle(LuumTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12), cornerRadius: 28, shadowOpacity: 0.12)
                } else if filteredItems.isEmpty {
                    Text("Nada encontrado para essa busca.")
                        .foregroundStyle(LuumTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.12), cornerRadius: 28, shadowOpacity: 0.12)
                } else {
                    VStack(spacing: 10) {
                        ForEach(visibleItems) { item in
                            QuickClassificationRow(store: store, kind: kind, item: item)
                        }
                    }

                    if hiddenItemCount > 0 {
                        Button("Mostrar mais \(hiddenItemCount) itens") {
                            showsAllItems = true
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(LuumTheme.textSecondary)
                    } else if showsAllItems && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && items.count > collapsedItemLimit {
                        Button("Mostrar menos") {
                            showsAllItems = false
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(LuumTheme.textSecondary)
                    }
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .onChange(of: selectedDay) { _, _ in
            showsAllItems = false
            searchText = ""
        }
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LuumTheme.textMuted)

                    TextField(kind.searchPrompt, text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.03))
                )

                CompactStatPill(
                    title: "\(filteredItems.count)",
                    detail: kind.itemCountLabel
                )

                CompactStatPill(
                    title: LuumFormatters.duration(totalVisibleDuration),
                    detail: "tempo visivel"
                )
            }

            Text(kind.helperText)
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let message = store.aiClassificationStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.1), cornerRadius: 28, shadowOpacity: 0.1)
    }
}

private struct QuickClassificationRow: View {
    @Bindable var store: ActivityStore
    let kind: QuickClassificationKind
    let item: UsageBreakdownItem

    private var selectedCategory: ActivityCategory {
        _ = store.summaryRevision
        return item.category ?? store.category(for: ActivityCategory.uncategorized.id) ?? .uncategorized
    }

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(selectedCategory.tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let secondaryLabel = item.secondaryLabel {
                        Text(secondaryLabel)
                            .font(.caption)
                            .foregroundStyle(LuumTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 12)

            Text(LuumFormatters.duration(item.duration))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            Menu {
                ForEach(store.categories) { category in
                    Button {
                        kind.applyCategory(for: item, categoryID: category.id, using: store)
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                    }
                }
            } label: {
                CategoryMenuLabel(category: selectedCategory)
            }
            .menuStyle(.borderlessButton)

            Button {
                kind.classifyWithAI(item, using: store)
            } label: {
                Image(systemName: "sparkles")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .disabled(!store.aiClassificationConfigured || store.isClassifyingWithAI)
            .help(store.aiClassificationConfigured ? "Classificar com IA" : "Configure a IA nas preferencias")

            Button(role: .destructive) {
                kind.ignore(item, using: store)
            } label: {
                Image(systemName: "eye.slash")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .help(kind.ignoreLabel)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.02))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.05))
        }
    }
}

private struct CategoryMenuLabel: View {
    let category: ActivityCategory

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(category.tint)
                .frame(width: 8, height: 8)

            Text(category.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(LuumTheme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(category.glassTint.opacity(0.26))
        )
    }
}

struct CompactStatPill: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Text(detail)
                .font(.caption)
                .foregroundStyle(LuumTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.03))
        )
    }
}
