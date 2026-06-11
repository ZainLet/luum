import Foundation

struct FirebaseSubscriptionStatus: Decodable, Sendable {
    let locked: Bool
    let plan: String?
    let trial: Bool?
    let canceling: Bool?
    let expiresAt: TimeInterval?
    let trialEndsAt: TimeInterval?
    let daysRemaining: Int?
    let reason: String?
}

enum FirebaseAuthServiceError: LocalizedError {
    case invalidCallback
    case missingToken
    case invalidToken
    case invalidStatusEndpoint
    case statusRejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            "O retorno de login do Luum veio incompleto. Tente entrar novamente pelo site."
        case .missingToken:
            "O site nao enviou o token Firebase para o app."
        case .invalidToken:
            "Nao foi possivel ler o token Firebase recebido."
        case .invalidStatusEndpoint:
            "A URL da API de assinatura nao e valida."
        case let .statusRejected(reason):
            "A assinatura nao esta liberada: \(reason)."
        }
    }

    var isExplicitAuthRejection: Bool {
        switch self {
        case .missingToken, .invalidToken:
            true
        case let .statusRejected(reason):
            [
                "HTTP 401",
                "HTTP 403",
                "refresh HTTP 400",
                "refresh HTTP 401",
                "refresh HTTP 403",
            ].contains(reason)
        case .invalidCallback, .invalidStatusEndpoint:
            false
        }
    }
}

struct FirebaseAuthService {
    static let defaultBaseURL = "https://luum-app.vercel.app"
    static let firebaseProjectID = "luum-app"
    static let firebaseIssuer = "https://securetoken.google.com/luum-app"
    static let firebaseAPIKey = "AIzaSyAWV6ulpYb54Qrta1Fu4iuP9ocnyGNJ99M"

    var statusBaseURL: String
    private let session: URLSession

    init(statusBaseURL: String = FirebaseAuthService.defaultBaseURL, session: URLSession = .shared) {
        self.statusBaseURL = statusBaseURL
        self.session = session
    }

    static func resolvedBaseURL() -> String {
        return defaultBaseURL
    }

    static func loginURL() -> URL? {
        URL(string: "\(defaultBaseURL)/login.html?app=mac")
    }

    static func officialBackendURL(from candidate: String) -> URL? {
        guard
            let official = URL(string: defaultBaseURL),
            let url = URL(string: candidate.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.scheme == official.scheme,
            url.host == official.host,
            url.port == official.port
        else {
            return nil
        }

        return official
    }

    static func isOfficialFirebaseTokenPayload(_ payload: FirebaseIDTokenPayload) -> Bool {
        Self.nonBlank(payload.audience) == firebaseProjectID &&
        Self.nonBlank(payload.issuer) == firebaseIssuer
    }

    func session(from callbackURL: URL) throws -> LuumAuthSession {
        guard callbackURL.scheme == "luum", callbackURL.host == "auth" else {
            throw FirebaseAuthServiceError.invalidCallback
        }

        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let token = items.first(where: { $0.name == "token" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshToken = items.first(where: { $0.name == "refreshToken" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid = items.first(where: { $0.name == "uid" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let token, !token.isEmpty else { throw FirebaseAuthServiceError.missingToken }
        let payload = try decodeFirebaseToken(token)
        guard Self.isOfficialFirebaseTokenPayload(payload) else {
            throw FirebaseAuthServiceError.invalidToken
        }
        guard let resolvedUID = Self.nonBlank(payload.userID) else {
            throw FirebaseAuthServiceError.invalidToken
        }
        if let callbackUID = Self.nonBlank(uid), callbackUID != resolvedUID {
            throw FirebaseAuthServiceError.invalidToken
        }

        let issuedAt = payload.issuedAt.map { Date(timeIntervalSince1970: $0) } ?? Date()
        let trialEndsAt = Calendar.current.date(byAdding: .day, value: 7, to: issuedAt)

        return LuumAuthSession(
            uid: resolvedUID,
            email: payload.email ?? "",
            displayName: payload.name,
            idToken: token,
            refreshToken: Self.nonBlank(refreshToken),
            plan: .trial,
            subscriptionStatus: "trial",
            lockedReason: nil,
            expiresAt: payload.expiresAt.map { Date(timeIntervalSince1970: $0) },
            trialEndsAt: trialEndsAt,
            lastVerifiedAt: nil
        )
    }

    func verifiedSession(_ existing: LuumAuthSession, deviceID: String? = nil) async throws -> LuumAuthSession {
        var updated = existing
        let status: FirebaseSubscriptionStatus

        do {
            status = try await fetchSubscriptionStatus(idToken: updated.idToken, deviceID: deviceID)
        } catch FirebaseAuthServiceError.statusRejected("HTTP 401") {
            guard let refreshToken = Self.nonBlank(updated.refreshToken) else { throw FirebaseAuthServiceError.statusRejected("HTTP 401") }
            let refreshed = try await refreshFirebaseToken(refreshToken)
            updated.idToken = refreshed.idToken
            updated.refreshToken = Self.nonBlank(refreshed.refreshToken) ?? refreshToken
            if let expiresIn = TimeInterval(refreshed.expiresIn ?? "") {
                updated.expiresAt = Date().addingTimeInterval(expiresIn)
            }
            status = try await fetchSubscriptionStatus(idToken: updated.idToken, deviceID: deviceID)
        }

        updated.plan = LuumAccountPlan(remoteValue: status.plan ?? (status.trial == true ? "trial" : nil))
        updated.subscriptionStatus = status.trial == true
            ? "trial"
            : (status.locked ? (status.reason ?? "locked") : (status.canceling == true ? "canceling" : "active"))
        updated.lockedReason = status.locked ? status.reason ?? "locked" : nil
        updated.lastVerifiedAt = Date()

        if let expiresAt = status.expiresAt {
            let seconds = expiresAt > 9_999_999_999 ? expiresAt / 1000 : expiresAt
            updated.expiresAt = Date(timeIntervalSince1970: seconds)
        }

        if let trialEndsAt = status.trialEndsAt ?? (status.trial == true ? status.expiresAt : nil) {
            let seconds = trialEndsAt > 9_999_999_999 ? trialEndsAt / 1000 : trialEndsAt
            updated.trialEndsAt = Date(timeIntervalSince1970: seconds)
        }

        return updated
    }

    private func refreshFirebaseToken(_ refreshToken: String) async throws -> FirebaseTokenRefreshResponse {
        guard let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(Self.firebaseAPIKey)") else {
            throw FirebaseAuthServiceError.invalidStatusEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encoded = Self.formEncoded(refreshToken)
        request.httpBody = Data("grant_type=refresh_token&refresh_token=\(encoded)".utf8)

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200 ..< 300).contains(statusCode) else {
            throw FirebaseAuthServiceError.statusRejected("refresh HTTP \(statusCode)")
        }

        return try JSONDecoder().decode(FirebaseTokenRefreshResponse.self, from: data)
    }

    private func fetchSubscriptionStatus(idToken: String, deviceID: String?) async throws -> FirebaseSubscriptionStatus {
        let trimmed = statusBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let baseURL = Self.officialBackendURL(from: trimmed) else { throw FirebaseAuthServiceError.invalidStatusEndpoint }
        let url = baseURL.appending(path: "/api/auth/status")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        if let deviceID = Self.nonBlank(deviceID) {
            request.setValue(deviceID, forHTTPHeaderField: "X-Luum-Device-ID")
        }

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200 ..< 300).contains(statusCode) else {
            throw FirebaseAuthServiceError.statusRejected("HTTP \(statusCode)")
        }

        return try JSONDecoder().decode(FirebaseSubscriptionStatus.self, from: data)
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func formEncoded(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func decodeFirebaseToken(_ token: String) throws -> FirebaseIDTokenPayload {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { throw FirebaseAuthServiceError.invalidToken }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload) else { throw FirebaseAuthServiceError.invalidToken }
        return try JSONDecoder().decode(FirebaseIDTokenPayload.self, from: data)
    }
}
