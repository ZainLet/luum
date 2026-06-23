import SwiftUI

struct SearchView: View {
    let store: ActivityStore
    let jumpToResult: (GlobalSearchResult) -> Void

    @State private var query = ""

    private var results: [GlobalSearchResult] {
        store.searchResults(matching: query)
    }

    var body: some View {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleResults = trimmedQuery.isEmpty ? [] : results

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LuumSectionHeader(
                    eyebrow: "Busca",
                    title: "Encontre qualquer contexto",
                    subtitle: "Pesquise por apps, sites, notas, buscas no navegador e compromissos da agenda a partir de uma única caixa."
                )

                searchCard(resultsCount: visibleResults.count)

                if trimmedQuery.isEmpty {
                    helperCard(
                        title: "Comece digitando",
                        message: "Busque por um app, um dominio, um termo da aba, uma nota manual ou um evento do Google Calendar."
                    )
                } else if visibleResults.isEmpty {
                    helperCard(
                        title: "Nenhum resultado",
                        message: "O luum não encontrou nada nesse histórico local ou na janela de agenda sincronizada."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(visibleResults) { result in
                            Button {
                                jumpToResult(result)
                            } label: {
                                SearchResultRow(result: result)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }

    private func searchCard(resultsCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LuumTheme.textMuted)

                    TextField("Buscar contexto, site, nota ou evento", text: $query)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.03))
                )

                CompactStatPill(
                    title: "\(resultsCount)",
                    detail: "resultados"
                )
            }

            Text("Ao clicar em um resultado, o luum reposiciona a data e abre o contexto mais relevante.")
                .foregroundStyle(LuumTheme.textSecondary)
        }
        .padding(22)
        .luumGlassCard(tint: LuumTheme.secondaryAccent.opacity(0.14), cornerRadius: 30)
    }

    private func helperCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(message)
                .foregroundStyle(LuumTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .luumGlassCard(tint: LuumTheme.accent.opacity(0.12), cornerRadius: 28)
    }
}

private struct SearchResultRow: View {
    let result: GlobalSearchResult

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((result.category?.tint ?? LuumTheme.electricBlue).opacity(0.2))

                Image(systemName: result.kind == .activity ? "sparkles.rectangle.stack.fill" : "calendar")
                    .foregroundStyle(result.category?.tint ?? LuumTheme.electricBlue)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(result.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(LuumTheme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(result.footnote)
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textMuted)

                    Text(result.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(LuumTheme.textMuted)
                }
            }

            Spacer()

            if let category = result.category {
                Label(category.title, systemImage: category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(category.tint)
            }
        }
        .padding(18)
        .luumGlassCard(tint: (result.category?.tint ?? LuumTheme.electricBlue).opacity(0.12), cornerRadius: 24, shadowOpacity: 0.1)
    }
}
