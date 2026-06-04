import Foundation

struct AIClassificationRequest: Sendable {
    enum TargetKind: String, Sendable {
        case application
        case domain
    }

    let kind: TargetKind
    let label: String
    let secondaryLabel: String?
    let currentCategory: ActivityCategory?
    let categories: [ActivityCategory]
}

struct AIClassificationResult: Equatable, Sendable {
    let categoryID: String
    let confidence: Double
    let reason: String
}

enum AIClassificationServiceError: LocalizedError, Equatable {
    case disabled
    case missingAPIKey
    case invalidEndpoint
    case rejected(String)
    case invalidResponse
    case unknownCategory(String)
    case lowConfidence(Double)

    var errorDescription: String? {
        switch self {
        case .disabled:
            "Ative a IA de classificacao nas preferencias."
        case .missingAPIKey:
            "Salve uma chave Gemini para usar classificacao por IA."
        case .invalidEndpoint:
            "Endpoint da IA invalido."
        case let .rejected(reason):
            "A IA recusou a classificacao: \(reason)."
        case .invalidResponse:
            "A IA retornou uma resposta em formato inesperado."
        case let .unknownCategory(categoryID):
            "A IA sugeriu uma categoria inexistente: \(categoryID)."
        case let .lowConfidence(confidence):
            "A confianca da IA foi baixa demais (\(Int(confidence * 100))%)."
        }
    }
}

struct AIClassificationService {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func classify(
        request: AIClassificationRequest,
        settings: AIClassificationSettings,
        apiKey: String
    ) async throws -> AIClassificationResult {
        let settings = settings.normalized()
        guard settings.isEnabled else { throw AIClassificationServiceError.disabled }

        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { throw AIClassificationServiceError.missingAPIKey }

        guard
            var components = URLComponents(string: settings.endpointURL),
            components.scheme?.hasPrefix("http") == true,
            let host = components.host,
            !host.isEmpty
        else {
            throw AIClassificationServiceError.invalidEndpoint
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([basePath, "models/\(settings.model):generateContent"].filter { !$0.isEmpty }.joined(separator: "/"))

        guard let url = components.url else { throw AIClassificationServiceError.invalidEndpoint }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
        urlRequest.httpBody = try JSONEncoder().encode(GeminiGenerateContentRequest(prompt: prompt(for: request)))

        let (data, response) = try await session.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200 ..< 300).contains(statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"
            throw AIClassificationServiceError.rejected("HTTP \(statusCode): \(message)")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        guard let text = geminiResponse.text, let result = Self.result(from: text) else {
            throw AIClassificationServiceError.invalidResponse
        }

        let validCategoryIDs = Set(request.categories.map(\.id))
        guard validCategoryIDs.contains(result.categoryID) else {
            throw AIClassificationServiceError.unknownCategory(result.categoryID)
        }

        let confidence = min(max(result.confidence, 0), 1)
        guard confidence >= settings.minimumConfidence else {
            throw AIClassificationServiceError.lowConfidence(confidence)
        }

        return AIClassificationResult(
            categoryID: result.categoryID,
            confidence: confidence,
            reason: result.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func prompt(for request: AIClassificationRequest) -> String {
        let categories = request.categories
            .map { "- \($0.id): \($0.title)" }
            .joined(separator: "\n")
        let current = request.currentCategory.map { "\($0.id) (\($0.title))" } ?? "sem categoria confiavel"
        let secondary = request.secondaryLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "n/a"

        return """
        Voce e o classificador do Luum, um app de produtividade para macOS.
        Classifique o alvo em UMA das categorias permitidas, usando conhecimento geral do app/site, nome publico, bundle id, dominio e a provavel descricao web dele.

        Categorias permitidas:
        \(categories)

        Alvo:
        tipo: \(request.kind.rawValue)
        nome_ou_dominio: \(request.label)
        detalhe: \(secondary)
        categoria_atual: \(current)

        Regras:
        - Responda apenas JSON valido.
        - Use exatamente um categoryID permitido.
        - confidence deve ficar entre 0 e 1.
        - reason deve ser curta, em portugues, com no maximo 120 caracteres.

        Formato:
        {"categoryID":"work","confidence":0.82,"reason":"Ambiente de desenvolvimento/produtividade."}
        """
    }

    static func result(from text: String) -> AIClassificationResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText: String

        if let range = trimmed.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) {
            jsonText = String(trimmed[range])
        } else {
            jsonText = trimmed
        }

        guard let data = jsonText.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(AIClassificationResultPayload.self, from: data)
        else {
            return nil
        }

        return AIClassificationResult(
            categoryID: decoded.categoryID,
            confidence: decoded.confidence,
            reason: decoded.reason
        )
    }
}

private struct GeminiGenerateContentRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig

    init(prompt: String) {
        self.contents = [GeminiContent(parts: [GeminiPart(text: prompt)])]
        self.generationConfig = GeminiGenerationConfig(
            temperature: 0.1,
            responseMimeType: "application/json"
        )
    }
}

private struct GeminiContent: Encodable, Decodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable, Decodable {
    let text: String?
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Double
    let responseMimeType: String
}

private struct GeminiGenerateContentResponse: Decodable {
    let candidates: [GeminiCandidate]?

    var text: String? {
        candidates?.lazy
            .compactMap { $0.content.parts.compactMap(\.text).joined(separator: "\n").nilIfBlank }
            .first
    }
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

private struct AIClassificationResultPayload: Decodable {
    let categoryID: String
    let confidence: Double
    let reason: String
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
