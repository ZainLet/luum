import AppKit
import CryptoKit
import Foundation
import Network

struct GoogleCalendarSyncResult {
    let tokens: GoogleCalendarTokens
    let profile: GoogleCalendarProfile?
    let calendars: [GoogleCalendarDescriptor]
    let events: [CalendarAgendaItem]
    let syncedAt: Date
}

enum GoogleCalendarIssue: LocalizedError {
    case missingClientID
    case localCallbackFailed
    case browserOpenFailed
    case consentDenied
    case invalidCallback
    case invalidState
    case invalidTokenResponse
    case invalidEventPayload
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            "Informe um OAuth Client ID do tipo Desktop app para conectar a Google Agenda."
        case .localCallbackFailed:
            "Nao foi possivel iniciar o retorno local do OAuth no macOS."
        case .browserOpenFailed:
            "O luum nao conseguiu abrir o navegador para iniciar o login do Google."
        case .consentDenied:
            "A conexao com a Google Agenda foi cancelada ou negada."
        case .invalidCallback:
            "O Google devolveu um retorno invalido para a autenticacao."
        case .invalidState:
            "O estado do OAuth nao confere. A conexao foi interrompida para proteger a sua sessao."
        case .invalidTokenResponse:
            "O Google nao devolveu um token valido para a Google Agenda."
        case .invalidEventPayload:
            "A Google Agenda respondeu sem dados de eventos utilizaveis."
        case let .apiError(message):
            message
        }
    }
}

struct GoogleCalendarService: Sendable {
    private static let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"
    private static let identityScopes = ["openid", "email", "profile"]
    private static let authEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    private static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    private static let calendarListEndpoint = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
    fileprivate static let oauthCallbackPath = "/oauth2callback"
    private static let agendaWindowDays = 3

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func connect(clientID: String, clientSecret: String, day: Date) async throws -> GoogleCalendarSyncResult {
        let normalizedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedClientID.isEmpty else {
            throw GoogleCalendarIssue.missingClientID
        }

        let receiver = try OAuthLoopbackReceiver()
        let redirectURL = try await receiver.start()
        defer { receiver.cancel() }

        let codeVerifier = Self.makeCodeVerifier()
        let state = UUID().uuidString.lowercased()
        let scopes = Self.identityScopes + [Self.calendarScope]
        let authURL = try authorizationURL(
            clientID: normalizedClientID,
            redirectURL: redirectURL,
            scopes: scopes,
            state: state,
            codeVerifier: codeVerifier
        )

        let opened = await MainActor.run {
            NSWorkspace.shared.open(authURL)
        }

        guard opened else {
            throw GoogleCalendarIssue.browserOpenFailed
        }

        let callback = try await receiver.waitForCallback()

        guard callback.state == state else {
            throw GoogleCalendarIssue.invalidState
        }

        let tokens = try await exchangeAuthorizationCode(
            clientID: normalizedClientID,
            clientSecret: clientSecret,
            code: callback.code,
            codeVerifier: codeVerifier,
            redirectURL: redirectURL
        )

        let profile = Self.profile(fromIDToken: tokens.idToken)
        let calendars = try await fetchCalendars(accessToken: tokens.accessToken)
        let selectedCalendarIDs = calendars.filter(\.isSelected).map(\.id)
        let events = try await fetchAgenda(
            day: day,
            accessToken: tokens.accessToken,
            accountID: profile?.email ?? UUID().uuidString.lowercased(),
            accountLabel: profile?.name ?? profile?.email ?? "Google Agenda",
            accountEmail: profile?.email ?? "Google Agenda",
            calendars: calendars.filter { selectedCalendarIDs.contains($0.id) }
        )

        return GoogleCalendarSyncResult(
            tokens: tokens,
            profile: profile,
            calendars: calendars,
            events: events,
            syncedAt: Date()
        )
    }

    func refresh(
        day: Date,
        clientID: String,
        clientSecret: String,
        existingTokens: GoogleCalendarTokens,
        connectionID: String,
        connectionProfile: GoogleCalendarProfile,
        existingCalendars: [GoogleCalendarDescriptor]
    ) async throws -> GoogleCalendarSyncResult {
        let activeTokens = try await refreshedTokensIfNeeded(
            clientID: clientID,
            clientSecret: clientSecret,
            existingTokens: existingTokens
        )

        let refreshedProfile = Self.profile(fromIDToken: activeTokens.idToken) ?? connectionProfile
        let remoteCalendars = try await fetchCalendars(accessToken: activeTokens.accessToken)
        let mergedCalendars = merge(remoteCalendars: remoteCalendars, existingCalendars: existingCalendars)
        let events = try await fetchAgenda(
            day: day,
            accessToken: activeTokens.accessToken,
            accountID: connectionID,
            accountLabel: refreshedProfile.name,
            accountEmail: refreshedProfile.email,
            calendars: mergedCalendars.filter(\.isSelected)
        )

        return GoogleCalendarSyncResult(
            tokens: activeTokens,
            profile: refreshedProfile,
            calendars: mergedCalendars,
            events: events,
            syncedAt: Date()
        )
    }

    private func authorizationURL(
        clientID: String,
        redirectURL: URL,
        scopes: [String],
        state: String,
        codeVerifier: String
    ) throws -> URL {
        var components = URLComponents(url: Self.authEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "include_granted_scopes", value: "true"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: Self.codeChallenge(for: codeVerifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]

        guard let url = components?.url else {
            throw GoogleCalendarIssue.invalidCallback
        }

        return url
    }

    private func exchangeAuthorizationCode(
        clientID: String,
        clientSecret: String,
        code: String,
        codeVerifier: String,
        redirectURL: URL
    ) async throws -> GoogleCalendarTokens {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
        ]

        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSecret.isEmpty {
            bodyItems.append(URLQueryItem(name: "client_secret", value: trimmedSecret))
        }

        request.httpBody = bodyItems.percentEncodedQuery.data(using: .utf8)

        let response: TokenResponse = try await perform(request)

        guard let refreshToken = response.refreshToken else {
            throw GoogleCalendarIssue.invalidTokenResponse
        }

        return GoogleCalendarTokens(
            accessToken: response.accessToken,
            refreshToken: refreshToken,
            idToken: response.idToken,
            tokenType: response.tokenType,
            scope: response.scope,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
    }

    private func refreshedTokensIfNeeded(
        clientID: String,
        clientSecret: String,
        existingTokens: GoogleCalendarTokens
    ) async throws -> GoogleCalendarTokens {
        guard existingTokens.needsRefresh else {
            return existingTokens
        }

        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "refresh_token", value: existingTokens.refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
        ]

        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSecret.isEmpty {
            bodyItems.append(URLQueryItem(name: "client_secret", value: trimmedSecret))
        }

        request.httpBody = bodyItems.percentEncodedQuery.data(using: .utf8)

        let response: TokenResponse = try await perform(request)

        return GoogleCalendarTokens(
            accessToken: response.accessToken,
            refreshToken: existingTokens.refreshToken,
            idToken: response.idToken ?? existingTokens.idToken,
            tokenType: response.tokenType,
            scope: response.scope.isEmpty ? existingTokens.scope : response.scope,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
    }

    private func fetchCalendars(accessToken: String) async throws -> [GoogleCalendarDescriptor] {
        var request = URLRequest(url: Self.calendarListEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let response: CalendarListResponse = try await perform(request)
        let calendars = response.items
            .map { item in
                GoogleCalendarDescriptor(
                    id: item.id,
                    title: item.summaryOverride?.nilIfBlank ?? item.summary?.nilIfBlank ?? item.id,
                    colorHex: item.backgroundColor?.nilIfBlank,
                    isPrimary: item.primary ?? false,
                    isSelected: (item.selected ?? true) && !(item.hidden ?? false),
                    isHidden: item.hidden ?? false,
                    accessRole: item.accessRole
                )
            }
            .sorted { lhs, rhs in
                if lhs.isPrimary != rhs.isPrimary {
                    return lhs.isPrimary && !rhs.isPrimary
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

        return calendars.isEmpty
            ? [GoogleCalendarDescriptor(id: "primary", title: "Principal", isPrimary: true, isSelected: true)]
            : calendars
    }

    private func fetchAgenda(
        day: Date,
        accessToken: String,
        accountID: String,
        accountLabel: String,
        accountEmail: String,
        calendars: [GoogleCalendarDescriptor]
    ) async throws -> [CalendarAgendaItem] {
        let calendar = Calendar.autoupdatingCurrent
        let dayStart = calendar.startOfDay(for: day)
        let rangeStart = dayStart
        let rangeEnd = calendar.date(byAdding: .day, value: Self.agendaWindowDays + 1, to: dayStart) ?? dayStart.addingTimeInterval(Double(Self.agendaWindowDays + 1) * 86_400)
        let visibleCalendars = calendars.filter { $0.isSelected && !$0.isHidden }

        return try await withThrowingTaskGroup(of: [CalendarAgendaItem].self) { group in
            for calendarDescriptor in visibleCalendars {
                group.addTask {
                    let url = try Self.eventsURL(
                        calendarID: calendarDescriptor.id,
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd
                    )

                    var request = URLRequest(url: url)
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

                    let response: EventsResponse = try await perform(request)
                    return response.items.compactMap {
                        Self.makeAgendaItem(
                            from: $0,
                            accountID: accountID,
                            accountEmail: accountEmail,
                            accountLabel: accountLabel,
                            calendar: calendarDescriptor
                        )
                    }
                }
            }

            var merged: [CalendarAgendaItem] = []
            for try await items in group {
                merged.append(contentsOf: items)
            }

            return merged.sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.endDate < rhs.endDate
                }
                return lhs.startDate < rhs.startDate
            }
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500

        guard (200 ..< 300).contains(statusCode) else {
            if let apiError = try? JSONDecoder().decode(GoogleAPIErrorEnvelope.self, from: data) {
                throw GoogleCalendarIssue.apiError(apiError.error.message)
            }

            throw GoogleCalendarIssue.apiError("A Google Agenda respondeu com status \(statusCode).")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GoogleCalendarIssue.apiError("Nao foi possivel interpretar a resposta da Google Agenda.")
        }
    }

    private static func makeAgendaItem(
        from event: EventResponseItem,
        accountID: String,
        accountEmail: String,
        accountLabel: String,
        calendar: GoogleCalendarDescriptor
    ) -> CalendarAgendaItem? {
        guard event.status != "cancelled" else {
            return nil
        }

        guard let start = date(from: event.start) else {
            return nil
        }

        let end = date(from: event.end) ?? start.addingTimeInterval(1_800)
        let isAllDay = event.start?.date != nil

        return CalendarAgendaItem(
            id: "\(accountID)::\(calendar.id)::\(event.id)",
            accountID: accountID,
            accountEmail: accountEmail,
            accountLabel: accountLabel,
            calendarID: calendar.id,
            calendarTitle: calendar.title,
            calendarColorHex: calendar.colorHex,
            title: event.summary?.nilIfBlank ?? "Sem titulo",
            location: event.location?.nilIfBlank,
            notes: event.description?.nilIfBlank,
            startDate: start,
            endDate: adjustedEndDate(start: start, end: end, allDay: isAllDay),
            isAllDay: isAllDay,
            htmlLink: event.htmlLink
        )
    }

    private static func adjustedEndDate(start: Date, end: Date, allDay: Bool) -> Date {
        guard allDay else {
            return max(end, start.addingTimeInterval(60))
        }

        let adjusted = end.addingTimeInterval(-60)
        return max(adjusted, start.addingTimeInterval(43_200))
    }

    private static func date(from value: EventDateValue?) -> Date? {
        guard let value else { return nil }

        if let dateTime = value.dateTime {
            return makeISO8601Formatter().date(from: dateTime)
        }

        if let date = value.date {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: date)
        }

        return nil
    }

    private static func profile(fromIDToken idToken: String?) -> GoogleCalendarProfile? {
        guard
            let idToken,
            let payload = idToken.split(separator: ".").dropFirst().first,
            let data = Data(base64URLEncoded: String(payload)),
            let claims = try? JSONDecoder().decode(IDTokenClaims.self, from: data),
            let email = claims.email
        else {
            return nil
        }

        return GoogleCalendarProfile(
            email: email,
            name: claims.name ?? email,
            pictureURL: claims.picture
        )
    }

    private static func makeCodeVerifier() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let length = 64

        return String((0 ..< length).compactMap { _ in
            characters.randomElement()
        })
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func isoTimestamp(_ date: Date) -> String {
        makeISO8601Formatter().string(from: date)
    }

    private static func eventsURL(calendarID: String, rangeStart: Date, rangeEnd: Date) throws -> URL {
        let encodedCalendarID = calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarID
        guard var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalendarID)/events") else {
            throw GoogleCalendarIssue.invalidEventPayload
        }

        components.queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: Self.isoTimestamp(rangeStart)),
            URLQueryItem(name: "timeMax", value: Self.isoTimestamp(rangeEnd)),
            URLQueryItem(name: "maxResults", value: "250"),
        ]

        guard let url = components.url else {
            throw GoogleCalendarIssue.invalidEventPayload
        }

        return url
    }

    private func merge(
        remoteCalendars: [GoogleCalendarDescriptor],
        existingCalendars: [GoogleCalendarDescriptor]
    ) -> [GoogleCalendarDescriptor] {
        let existingSelection = Dictionary(uniqueKeysWithValues: existingCalendars.map { ($0.id, $0) })

        return remoteCalendars.map { remote in
            guard let existing = existingSelection[remote.id] else { return remote }
            var merged = remote
            merged.isSelected = existing.isSelected
            return merged
        }
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let idToken: String?
    let scope: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case scope
        case tokenType = "token_type"
    }
}

private struct GoogleAPIErrorEnvelope: Decodable {
    let error: GoogleAPIError
}

private struct GoogleAPIError: Decodable {
    let message: String
}

private struct EventsResponse: Decodable {
    let items: [EventResponseItem]
}

private struct CalendarListResponse: Decodable {
    let items: [CalendarListItem]
}

private struct CalendarListItem: Decodable {
    let id: String
    let summary: String?
    let summaryOverride: String?
    let backgroundColor: String?
    let accessRole: String?
    let primary: Bool?
    let hidden: Bool?
    let selected: Bool?
}

private struct EventResponseItem: Decodable {
    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let htmlLink: String?
    let status: String?
    let start: EventDateValue?
    let end: EventDateValue?
}

private struct EventDateValue: Decodable {
    let date: String?
    let dateTime: String?

    enum CodingKeys: String, CodingKey {
        case date
        case dateTime
    }
}

private struct IDTokenClaims: Decodable {
    let email: String?
    let name: String?
    let picture: String?
}

private struct OAuthCallback {
    let code: String
    let state: String
}

private final class OAuthLoopbackReceiver: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.zainlet.luum.oauth-loopback")

    private var hasStarted = false
    private var pendingCallback: Result<OAuthCallback, Error>?
    private var callbackContinuation: CheckedContinuation<OAuthCallback, Error>?

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
    }

    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                guard !self.hasStarted else { return }

                switch state {
                case .ready:
                    self.hasStarted = true

                    guard let port = self.listener.port?.rawValue else {
                        continuation.resume(throwing: GoogleCalendarIssue.localCallbackFailed)
                        return
                    }

                    let redirect = URL(string: "http://127.0.0.1:\(port)\(GoogleCalendarService.oauthCallbackPath)")!
                    continuation.resume(returning: redirect)
                case let .failed(error):
                    self.hasStarted = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }

            listener.start(queue: queue)
        }
    }

    func waitForCallback() async throws -> OAuthCallback {
        if let pendingCallback {
            self.pendingCallback = nil
            return try pendingCallback.get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            callbackContinuation = continuation
        }
    }

    func cancel() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, _ in
            guard let self else { return }

            let result = Self.parseCallback(from: data)
            self.respond(to: connection, result: result)
            self.finish(with: result)
        }
    }

    private func finish(with result: Result<OAuthCallback, Error>) {
        if let callbackContinuation {
            self.callbackContinuation = nil
            callbackContinuation.resume(with: result)
        } else {
            pendingCallback = result
        }
    }

    private func respond(to connection: NWConnection, result: Result<OAuthCallback, Error>) {
        let body: String
        let statusLine: String

        switch result {
        case .success:
            statusLine = "HTTP/1.1 200 OK"
            body = """
            <html><body style="font-family:-apple-system;background:#09060f;color:#f6f2ff;padding:32px;">
            <h1 style="margin-bottom:12px;">Google Agenda conectada ao luum</h1>
            <p>Voce pode fechar esta aba e voltar para o app.</p>
            </body></html>
            """
        case .failure:
            statusLine = "HTTP/1.1 400 Bad Request"
            body = """
            <html><body style="font-family:-apple-system;background:#09060f;color:#f6f2ff;padding:32px;">
            <h1 style="margin-bottom:12px;">Nao foi possivel concluir a conexao</h1>
            <p>Volte para o luum e tente novamente.</p>
            </body></html>
            """
        }

        let response = """
        \(statusLine)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func parseCallback(from data: Data?) -> Result<OAuthCallback, Error> {
        guard
            let data,
            let request = String(data: data, encoding: .utf8),
            let requestLine = request.split(separator: "\n").first
        else {
            return .failure(GoogleCalendarIssue.invalidCallback)
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return .failure(GoogleCalendarIssue.invalidCallback)
        }

        let target = String(parts[1])
        guard let components = URLComponents(string: "http://127.0.0.1\(target)") else {
            return .failure(GoogleCalendarIssue.invalidCallback)
        }

        let queryItems = components.queryItems ?? []

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            if error == "access_denied" {
                return .failure(GoogleCalendarIssue.consentDenied)
            }

            return .failure(GoogleCalendarIssue.apiError("O Google devolveu um erro durante a autorizacao: \(error)."))
        }

        guard
            let code = queryItems.first(where: { $0.name == "code" })?.value,
            let state = queryItems.first(where: { $0.name == "state" })?.value
        else {
            return .failure(GoogleCalendarIssue.invalidCallback)
        }

        return .success(OAuthCallback(code: code, state: state))
    }
}

private func makeISO8601Formatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}

private extension Array where Element == URLQueryItem {
    var percentEncodedQuery: String {
        var components = URLComponents()
        components.queryItems = self
        return components.percentEncodedQuery ?? ""
    }
}

private extension Data {
    init?(base64URLEncoded string: String) {
        var encoded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = encoded.count % 4
        if remainder > 0 {
            encoded += String(repeating: "=", count: 4 - remainder)
        }

        self.init(base64Encoded: encoded)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
