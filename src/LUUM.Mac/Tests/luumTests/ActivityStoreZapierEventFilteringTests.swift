import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@MainActor
@Test
func zapierCalendarSyncDeliversOnlyToMatchingWebhooks() async throws {
    let context = try makeZapierEventFilterTestContext()
    defer { context.cleanup() }

    try context.keychain.setCodable(
        LuumAuthSession(
            uid: "zapier-filter-test",
            email: "zapier@example.com",
            displayName: "Zapier Filter Test",
            idToken: "test-token",
            refreshToken: nil,
            plan: .equipes,
            subscriptionStatus: "active",
            lockedReason: nil,
            expiresAt: Date().addingTimeInterval(3_600),
            trialEndsAt: nil,
            lastVerifiedAt: Date()
        ),
        for: "firebase-auth-session"
    )

    ZapierEventFilterURLProtocol.reset()
    URLProtocol.registerClass(ZapierEventFilterURLProtocol.self)
    defer { URLProtocol.unregisterClass(ZapierEventFilterURLProtocol.self) }

    let store = ActivityStore(
        persistence: ActivityPersistence(directoryURL: context.temporaryDirectory.appendingPathComponent("activity")),
        googleCalendarPersistence: GoogleCalendarPersistence(fileManager: context.fileManager),
        monitoringPreferencesPersistence: MonitoringPreferencesPersistence(fileManager: context.fileManager),
        keychainService: context.keychain
    )
    store.authSession = context.keychain.codable(LuumAuthSession.self, for: "firebase-auth-session")
    store.monitoringPreferences.zapierSettings = ZapierSettings(
        isEnabled: true,
        webhooks: [
            ZapierWebhook(
                url: "https://zapier-filter.test/matching",
                label: "Calendar Sync",
                events: [ZapierEvent.calendarSync.rawValue]
            ),
            ZapierWebhook(
                url: "https://zapier-filter.test/ignored",
                label: "Manual Test",
                events: [ZapierEvent.manualTest.rawValue]
            ),
        ],
        sendsFocusEvents: true,
        sendsCalendarSyncEvents: true,
        sendsWorkspaceRankingEvents: true,
        lastDeliveryAt: nil
    )

    await store.sendZapierCalendarSyncEventIfNeeded(source: "linear", itemCount: 3)

    let requests = ZapierEventFilterURLProtocol.observedRequests
    #expect(requests.count == 1)
    let request = try #require(requests.first)
    #expect(request.url?.absoluteString == "https://zapier-filter.test/matching")

    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let eventType = try #require(json["eventType"] as? String)
    let details = try #require(json["details"] as? [String: String])

    #expect(eventType == ZapierEvent.calendarSync.rawValue)
    #expect(details["source"] == "linear")
    #expect(details["items"] == "3")
    #expect(store.zapierStatusMessage == "Webhook do Zapier entregue com sucesso.")
    #expect(store.zapierSettings.lastDeliveryAt != nil)
}

private func makeZapierEventFilterTestContext() throws -> ZapierEventFilterTestContext {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("luum-zapier-filter-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    let fileManager = TemporaryZapierTestFileManager(directoryURL: temporaryDirectory)
    let keychain = KeychainService(
        installationSecretURL: temporaryDirectory.appendingPathComponent(".local-vault-key")
    )
    return ZapierEventFilterTestContext(
        temporaryDirectory: temporaryDirectory,
        fileManager: fileManager,
        keychain: keychain
    )
}

private struct ZapierEventFilterTestContext {
    let temporaryDirectory: URL
    let fileManager: TemporaryZapierTestFileManager
    let keychain: KeychainService

    func cleanup() {
        keychain.removeValue(for: "firebase-auth-session")
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}

private final class TemporaryZapierTestFileManager: FileManager, @unchecked Sendable {
    private let directoryURL: URL

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        super.init()
    }

    override func urls(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
        if directory == .applicationSupportDirectory, domainMask.contains(.userDomainMask) {
            return [directoryURL]
        }
        return super.urls(for: directory, in: domainMask)
    }
}

private final class ZapierEventFilterURLProtocol: URLProtocol, @unchecked Sendable {
    private nonisolated(unsafe) static let storageQueue = DispatchQueue(label: "luum.zapier-filter-test-url-protocol")
    private nonisolated(unsafe) static var storedObservedRequests: [URLRequest] = []

    static var observedRequests: [URLRequest] {
        storageQueue.sync { storedObservedRequests }
    }

    static func reset() {
        storageQueue.sync {
            storedObservedRequests = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "zapier-filter.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.storageQueue.sync {
            Self.storedObservedRequests.append(request)
        }

        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://zapier-filter.test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"ok":true}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
#endif
