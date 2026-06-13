import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func cloudBackupRemovesZapierWebhookURL() {
    var preferences = MonitoringPreferencesSnapshot.default
    preferences.zapierSettings.webhookURL = "https://hooks.zapier.com/hooks/catch/secret"
    preferences.aiClassificationSettings.endpointURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini"
    preferences.aiClassificationSettings.providerName = "Gemini direto"

    let sanitized = CloudSyncService.cloudSafePreferences(preferences)

    #expect(sanitized.zapierSettings.webhookURL.isEmpty)
    #expect(sanitized.aiClassificationSettings.endpointURL == AIClassificationSettings.default.endpointURL)
    #expect(sanitized.aiClassificationSettings.providerName == AIClassificationSettings.default.providerName)
}

@Test
func cloudBackupKeepsIntegrationMetadataWithoutLocalSecrets() {
    var preferences = MonitoringPreferencesSnapshot.default
    preferences.notionCalendarSettings = NotionCalendarSettings(
        isEnabled: true,
        workspaceLabel: "Notion Ops",
        databaseIDs: ["12345678-1234-1234-1234-1234567890ab"],
        datePropertyName: "Date",
        titlePropertyName: "Name",
        lastSyncAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    preferences.clickUpSettings = ClickUpSettings(
        isEnabled: true,
        workspaceLabel: "ClickUp Ops",
        workspaceID: "workspace",
        listIDs: ["list-a"],
        includeClosedTasks: true,
        lastSyncAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    preferences.linearSettings = LinearSettings(
        isEnabled: true,
        workspaceLabel: "Linear Ops",
        workspaceID: "linear-workspace",
        teamIDs: ["team-a"],
        includeCompletedIssues: true,
        lastSyncAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    preferences.teamSettings.workspaceEndpointURL = "https://evil.example"
    preferences.zapierSettings.webhookURL = "https://hooks.zapier.com/hooks/catch/private"

    let sanitized = CloudSyncService.cloudSafePreferences(preferences).normalized()

    #expect(sanitized.notionCalendarSettings.databaseIDs == ["12345678-1234-1234-1234-1234567890ab"])
    #expect(sanitized.clickUpSettings.listIDs == ["list-a"])
    #expect(sanitized.linearSettings.teamIDs == ["team-a"])
    #expect(sanitized.zapierSettings.webhookURL.isEmpty)
    #expect(sanitized.teamSettings.workspaceEndpointURL == FirebaseAuthService.defaultBaseURL)
}

@Test
func cloudBackupKeepsCalendarStructureWithoutCachedEventsOrTokens() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let connection = GoogleCalendarConnectionSnapshot(
        id: "user-at-luum-app",
        profile: GoogleCalendarProfile(email: "user@luum.app", name: "User", pictureURL: nil),
        calendars: [GoogleCalendarDescriptor(id: "primary", title: "Principal", isPrimary: true)],
        agendaDay: now,
        agendaItems: [
            CalendarAgendaItem(
                id: "private-event",
                accountID: "user-at-luum-app",
                accountEmail: "user@luum.app",
                accountLabel: "User",
                calendarID: "primary",
                calendarTitle: "Principal",
                calendarColorHex: nil,
                title: "Reuniao confidencial",
                location: "Sala secreta",
                notes: "Nao enviar ao Firestore",
                startDate: now,
                endDate: now.addingTimeInterval(1800),
                isAllDay: false,
                htmlLink: nil
            ),
        ],
        lastSyncAt: now,
        legacyTokens: GoogleCalendarTokens(
            accessToken: "access",
            refreshToken: "refresh",
            idToken: "id",
            tokenType: "Bearer",
            scope: "calendar",
            expiresAt: now.addingTimeInterval(3600)
        )
    )

    let sanitized = CloudSyncService.cloudSafeGoogleCalendarSnapshot(
        clientID: "public-client-id",
        connections: [connection]
    )

    #expect(sanitized.clientID == "public-client-id")
    #expect(sanitized.clientSecret.isEmpty)
    #expect(sanitized.connections.first?.calendars.first?.id == "primary")
    #expect(sanitized.connections.first?.agendaDay == nil)
    #expect(sanitized.connections.first?.agendaItems.isEmpty == true)
    #expect(sanitized.connections.first?.legacyTokens == nil)
}

@Test
func plansExposeOnlyTheirAllowedIntegrationTiers() {
    #expect(!LuumAccountPlan.essencial.includes(.agendaIntegrations))
    #expect(LuumAccountPlan.profissional.includes(.agendaIntegrations))
    #expect(!LuumAccountPlan.profissional.includes(.advancedIntegrations))
    #expect(LuumAccountPlan.equipes.includes(.advancedIntegrations))
    #expect(LuumAccountPlan.equipes.includes(.teamWorkspace))
    #expect(!LuumAccountPlan.equipes.includes(.rawActivityBackup))
    #expect(LuumAccountPlan.negocios.includes(.rawActivityBackup))
}

@Test
func lockedAuthSessionDoesNotEnableCloudOrRawBackup() {
    var settings = CloudSyncSettings.default
    settings.isEnabled = true
    settings.syncRawActivities = true

    let sanitized = ActivityStore.cloudSyncSettings(
        settings,
        sanitizedFor: makeAuthSession(plan: .trial, lastVerifiedAt: nil)
    )

    #expect(!sanitized.isEnabled)
    #expect(!sanitized.syncRawActivities)
    #expect(sanitized.endpointURL == FirebaseAuthService.defaultBaseURL)
    #expect(sanitized.backupID == "firebase-user")
}

@Test
func trialSessionMirrorsBackendEntitlementRestrictions() {
    let session = makeAuthSession(
        plan: .negocios,
        subscriptionStatus: "trial",
        lastVerifiedAt: Date()
    )

    #expect(session.includes(.cloudBackup))
    #expect(session.includes(.advancedIntegrations))
    #expect(!session.includes(.teamWorkspace))
    #expect(!session.includes(.rawActivityBackup))

    var settings = CloudSyncSettings.default
    settings.isEnabled = true
    settings.syncRawActivities = true

    let sanitized = ActivityStore.cloudSyncSettings(settings, sanitizedFor: session)
    #expect(sanitized.isEnabled)
    #expect(!sanitized.syncRawActivities)
}

@Test
func trialSessionUsesTrialFeatureMatrixEvenWhenBackendPlanIsEssencial() {
    let session = makeAuthSession(
        plan: .essencial,
        subscriptionStatus: "trial",
        lastVerifiedAt: Date()
    )

    #expect(session.includes(.cloudBackup))
    #expect(session.includes(.agendaIntegrations))
    #expect(session.includes(.advancedIntegrations))
    #expect(!session.includes(.teamWorkspace))
    #expect(!session.includes(.rawActivityBackup))
}

@Test
func businessPlanKeepsRawBackupPinnedToFirebaseAccount() {
    var settings = CloudSyncSettings.default
    settings.endpointURL = "https://evil.example"
    settings.backupID = "someone-else"
    settings.syncRawActivities = true

    let sanitized = ActivityStore.cloudSyncSettings(
        settings,
        sanitizedFor: makeAuthSession(plan: .negocios, lastVerifiedAt: Date())
    )

    #expect(sanitized.isEnabled)
    #expect(sanitized.syncRawActivities)
    #expect(sanitized.endpointURL == FirebaseAuthService.defaultBaseURL)
    #expect(sanitized.backupID == "firebase-user")
}

@Test
func firstEligibleAccountBindingEnablesCloudBackupAutomatically() {
    let sanitized = ActivityStore.cloudSyncSettings(
        .default,
        sanitizedFor: makeAuthSession(plan: .profissional, lastVerifiedAt: Date())
    )

    #expect(sanitized.isEnabled)
    #expect(sanitized.endpointURL == FirebaseAuthService.defaultBaseURL)
    #expect(sanitized.backupID == "firebase-user")
}

@Test
func existingAccountBindingPreservesManualCloudBackupDisable() {
    var settings = CloudSyncSettings.default
    settings.isEnabled = false
    settings.backupID = "firebase-user"

    let sanitized = ActivityStore.cloudSyncSettings(
        settings,
        sanitizedFor: makeAuthSession(plan: .profissional, lastVerifiedAt: Date())
    )

    #expect(!sanitized.isEnabled)
    #expect(sanitized.endpointURL == FirebaseAuthService.defaultBaseURL)
    #expect(sanitized.backupID == "firebase-user")
}

@Test
func cloudSyncConfiguredRequiresOfficialEndpointFirebaseUIDAndToken() {
    let session = makeAuthSession(plan: .profissional, lastVerifiedAt: Date())
    let settings = ActivityStore.cloudSyncSettings(.default, sanitizedFor: session)

    #expect(ActivityStore.isCloudSyncConfigured(settings, for: session))

    var wrongEndpoint = settings
    wrongEndpoint.endpointURL = "https://evil.example"
    #expect(!ActivityStore.isCloudSyncConfigured(wrongEndpoint, for: session))

    var wrongBackupID = settings
    wrongBackupID.backupID = "another-user"
    #expect(!ActivityStore.isCloudSyncConfigured(wrongBackupID, for: session))

    var emptyTokenSession = session
    emptyTokenSession.idToken = "  "
    #expect(!ActivityStore.isCloudSyncConfigured(settings, for: emptyTokenSession))
    #expect(!ActivityStore.isCloudSyncConfigured(settings, for: nil))
}

@Test
func cloudBackupPayloadDecodesLegacyPayloadWithoutAccount() throws {
    let payload = """
    {
      "schemaVersion": 1,
      "exportedAt": "2026-06-03T00:00:00Z",
      "deviceName": "Mac",
      "monitoringPreferences": {},
      "googleCalendarSnapshot": {
        "clientID": "",
        "clientSecret": "",
        "connections": []
      },
      "dailySummaries": [],
      "rawActivities": null
    }
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let decoded = try decoder.decode(CloudBackupPayload.self, from: payload)

    #expect(decoded.account == nil)
    #expect(decoded.dailySummaries.isEmpty)
}

@Test
func cloudBackupPayloadEncodesFirebaseAccountMetadataWithoutTokens() throws {
    let payload = CloudBackupPayload(
        schemaVersion: 1,
        exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
        deviceName: "Mac",
        account: CloudAccountSnapshot(
            uid: "firebase-user",
            email: "user@luum.app",
            displayName: "User",
            plan: .profissional,
            subscriptionStatus: "active"
        ),
        monitoringPreferences: .default,
        googleCalendarSnapshot: GoogleCalendarSnapshot(clientID: "", clientSecret: "", connections: []),
        dailySummaries: [],
        rawActivities: nil
    )
    let data = try JSONEncoder().encode(payload)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let account = object?["account"] as? [String: Any]

    #expect(account?["uid"] as? String == "firebase-user")
    #expect(account?["email"] as? String == "user@luum.app")
    #expect(account?["idToken"] == nil)
    #expect(account?["refreshToken"] == nil)
}

@Test
func cloudSyncExplainsMissingVercelRoute() async throws {
    let session = URLSession.cloudSyncMocking([
        CloudSyncMockResponse(
            url: "https://luum-app.vercel.app/api/sync/firebase-user",
            statusCode: 404,
            body: #"<!doctype html><title>404</title>"#
        )
    ])
    let service = CloudSyncService(session: session)

    do {
        _ = try await service.push(
            baseURL: FirebaseAuthService.defaultBaseURL,
            backupID: "firebase-user",
            firebaseToken: "firebase-token",
            payload: cloudBackupPayloadForTesting()
        )
        Issue.record("Erro 404 deveria explicar deploy/rota da Vercel.")
    } catch CloudSyncError.apiError(let message) {
        #expect(message.contains("/api/sync/[backupID]"))
        #expect(message.contains("Vercel"))
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

private func makeAuthSession(
    plan: LuumAccountPlan,
    subscriptionStatus: String = "active",
    lastVerifiedAt: Date?
) -> LuumAuthSession {
    LuumAuthSession(
        uid: "firebase-user",
        email: "user@luum.app",
        displayName: "User",
        idToken: "token",
        refreshToken: "refresh",
        plan: plan,
        subscriptionStatus: subscriptionStatus,
        lockedReason: nil,
        expiresAt: Date().addingTimeInterval(3600),
        trialEndsAt: nil,
        lastVerifiedAt: lastVerifiedAt
    )
}

private func cloudBackupPayloadForTesting() -> CloudBackupPayload {
    CloudBackupPayload(
        schemaVersion: 1,
        exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
        deviceName: "Mac",
        account: CloudAccountSnapshot(
            uid: "firebase-user",
            email: "user@luum.app",
            displayName: "User",
            plan: .profissional,
            subscriptionStatus: "active"
        ),
        monitoringPreferences: .default,
        googleCalendarSnapshot: GoogleCalendarSnapshot(clientID: "", clientSecret: "", connections: []),
        dailySummaries: [],
        rawActivities: nil
    )
}

private struct CloudSyncMockResponse: Sendable {
    let url: String
    let statusCode: Int
    let body: String
}

private final class CloudSyncMockURLProtocol: URLProtocol, @unchecked Sendable {
    private nonisolated(unsafe) static let storageQueue = DispatchQueue(label: "luum.cloud-sync-test-url-protocol")
    private nonisolated(unsafe) static var responses: [CloudSyncMockResponse] = []
    private nonisolated(unsafe) static var storedObservedRequests: [URLRequest] = []

    static var observedRequests: [URLRequest] {
        storageQueue.sync { storedObservedRequests }
    }

    static func configure(responses: [CloudSyncMockResponse]) {
        storageQueue.sync {
            self.responses = responses
            self.storedObservedRequests = []
        }
    }

    private static func appendObservedRequest(_ request: URLRequest) {
        storageQueue.sync {
            storedObservedRequests.append(request)
        }
    }

    private static func removeResponse(for url: String) -> CloudSyncMockResponse? {
        storageQueue.sync {
            guard let index = responses.firstIndex(where: { $0.url == url }) else { return nil }
            return responses.remove(at: index)
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.appendObservedRequest(request)
        guard let url = request.url?.absoluteString else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        guard let response = Self.removeResponse(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let data = Data(response.body.utf8)
        guard
            let requestURL = request.url,
            let httpResponse = HTTPURLResponse(
                url: requestURL,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func cloudSyncMocking(_ responses: [CloudSyncMockResponse]) -> URLSession {
        CloudSyncMockURLProtocol.configure(responses: responses)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CloudSyncMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
#endif
