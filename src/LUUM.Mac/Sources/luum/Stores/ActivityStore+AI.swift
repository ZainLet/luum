import Foundation

extension ActivityStore {
    // MARK: - AI Classification & Query

    func updateAIClassificationEnabled(_ value: Bool) {
        monitoringPreferences.aiClassificationSettings.isEnabled = value
        aiClassificationStatusMessage = value
            ? "IA de classificação ativada. O Luum usa a configuração segura da sua conta."
            : "IA de classificação desativada."
        persistMonitoringPreferences()
    }

    func updateAIClassificationEndpointURL(_ value: String) {
        monitoringPreferences.aiClassificationSettings.endpointURL = value
        persistMonitoringPreferences()
    }

    func updateAIClassificationModel(_ value: String) {
        monitoringPreferences.aiClassificationSettings.model = value
        persistMonitoringPreferences()
    }

    func updateAIClassificationMinimumConfidence(_ value: Double) {
        monitoringPreferences.aiClassificationSettings.minimumConfidence = value
        persistMonitoringPreferences()
    }

    func updateAIClassificationAPIKey(_ value: String) {
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.aiClassificationAPIKeyKey)
                aiClassificationStatusMessage = "Chave da IA removida deste Mac."
            } else {
                try keychainService.setString(value, for: Self.aiClassificationAPIKeyKey)
                aiClassificationStatusMessage = "Chave da IA salva no cofre local cifrado."
            }
        } catch {
            aiClassificationStatusMessage = "Nao foi possivel salvar a chave da IA."
        }
    }

    func classifyApplicationWithAI(_ item: UsageBreakdownItem) {
        aiClassificationTask?.cancel()
        aiClassificationTask = Task { [weak self] in
            await self?.runAIClassification(kind: .application, item: item)
        }
    }

    func classifyDomainWithAI(_ item: UsageBreakdownItem) {
        aiClassificationTask?.cancel()
        aiClassificationTask = Task { [weak self] in
            await self?.runAIClassification(kind: .domain, item: item)
        }
    }

    func sendAIQuery(_ question: String) {
        let clean = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isQueryingAI else { return }

        aiQueryTask?.cancel()
        isQueryingAI = true
        aiQueryError = nil

        aiQueryTask = Task { [weak self] in
            await self?.runAIQuery(clean)
        }
    }

    func clearAIQuery() {
        aiQueryTask?.cancel()
        aiQueryTask = nil
        isQueryingAI = false
        aiQueryResponse = nil
        aiQueryError = nil
    }

    private func runAIClassification(kind: AIClassificationRequest.TargetKind, item: UsageBreakdownItem) async {
        guard !isClassifyingWithAI else { return }

        guard canUse(.classification) else {
            aiClassificationStatusMessage = lockMessage(for: .classification)
            return
        }

        let settings = aiClassificationSettings
        guard settings.isEnabled else {
            aiClassificationStatusMessage = "Ative a IA de classificação nas preferências."
            return
        }

        let usesLuumBackend = AIClassificationService.isLuumBackendEndpoint(settings.endpointURL)
        let apiKey = keychainService.string(for: Self.aiClassificationAPIKeyKey)
        let verifiedSession: LuumAuthSession?

        if usesLuumBackend {
            do {
                let verified = try await verifiedAuthSessionForProtectedRequest()
                guard verified.includes(.classification) else {
                    aiClassificationStatusMessage = lockMessage(for: .classification)
                    return
                }
                verifiedSession = verified
            } catch {
                aiClassificationStatusMessage = error.localizedDescription
                return
            }
        } else {
            guard !(apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) else {
                aiClassificationStatusMessage = "Use a IA segura do Luum para classificar sem configurar chave no app."
                return
            }
            verifiedSession = nil
        }

        isClassifyingWithAI = true
        aiClassificationStatusMessage = "IA analisando \(item.label)..."
        defer { isClassifyingWithAI = false }

        do {
            let result = try await aiClassificationService.classify(
                request: AIClassificationRequest(
                    kind: kind,
                    label: item.label,
                    secondaryLabel: item.secondaryLabel,
                    currentCategory: item.category,
                    categories: categories
                ),
                settings: settings,
                apiKey: apiKey,
                firebaseToken: verifiedSession?.idToken
            )

            if let verifiedSession, !isCurrentVerifiedSession(verifiedSession) {
                return
            }

            guard let category = category(for: result.categoryID) else {
                throw AIClassificationServiceError.unknownCategory(result.categoryID)
            }

            switch kind {
            case .application:
                assignCategory(toApplication: item.label, categoryID: category.id)
            case .domain:
                assignCategory(toDomain: item.label, categoryID: category.id)
            }

            let confidence = Int((result.confidence * 100).rounded())
            let reason = result.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            aiClassificationStatusMessage = reason.isEmpty
                ? "IA classificou \(item.label) como \(category.title) (\(confidence)%)."
                : "IA classificou \(item.label) como \(category.title) (\(confidence)%): \(reason)"
        } catch is CancellationError {
            return
        } catch {
            aiClassificationStatusMessage = error.localizedDescription
        }
    }

    private func runAIQuery(_ question: String) async {
        defer { isQueryingAI = false }

        let todaySummary = summary(for: Date())
        let context = AIQueryContext(
            date: Date().formatted(.dateTime.year().month(.abbreviated).day()),
            totalTrackedTime: todaySummary.totalTrackedTime,
            categoryBreakdown: todaySummary.categoryBreakdown.prefix(8).map {
                AIQueryBreakdownItem(label: $0.category.title, duration: $0.duration)
            },
            topApps: todaySummary.appBreakdown.prefix(6).map {
                AIQueryBreakdownItem(label: $0.label, duration: $0.duration)
            },
            currentActivity: currentSnapshot != nil ? currentActivityTitle : nil
        )

        do {
            let verified = try await verifiedAuthSessionForProtectedRequest()
            guard !Task.isCancelled else { return }
            guard verified.includes(.classification) else {
                aiQueryError = lockMessage(for: .classification)
                return
            }

            let answer = try await aiQueryService.query(
                question,
                context: context,
                baseURL: FirebaseAuthService.defaultBaseURL,
                firebaseToken: verified.idToken
            )
            guard !Task.isCancelled else { return }
            aiQueryResponse = AIQueryResponse(query: question, answer: answer)
        } catch is CancellationError {
            return
        } catch let err as AIQueryServiceError {
            switch err {
            case .rejected:
                aiQueryError = "O assistente está temporariamente indisponível."
            default:
                aiQueryError = err.localizedDescription
            }
        } catch {
            aiQueryError = "O assistente está temporariamente indisponível."
        }
    }
}
