import Foundation
#if canImport(Testing)
import Testing
@testable import luum

private struct MockResponse: Sendable {
    let url: String
    let statusCode: Int
    let body: Data
}

private let mockAPIKey = "lin_api_key_123"

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [MockResponse] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        defer { client?.urlProtocolDidFinishLoading(self) }
        guard let response = Self.responses.first else { return }
        Self.responses.removeFirst()
        guard let requestURL = request.url?.absoluteString, requestURL == response.url else { return }
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func mocking(_ responses: [MockResponse]) -> URLSession {
        MockURLProtocol.responses = responses
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

private func makeSettings(teamIDs: [String] = ["TEAM"]) -> LinearSettings {
    LinearSettings(
        isEnabled: true,
        workspaceLabel: "MyTeam",
        workspaceID: "ws_1",
        teamIDs: teamIDs,
        includeCompletedIssues: false,
        lastSyncAt: nil
    )
}

private func jsonData(_ value: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
}

private let graphQLEndpoint = "https://api.linear.app/graphql"

private func teamResponseJSON(
    issues: [[String: Any?]]
) -> [String: Any] {
    let nodes: [Any] = issues.map { issue in
        var clean: [String: Any] = [:]
        for (key, val) in issue {
            if let val {
                clean[key] = val
            } else {
                clean[key] = NSNull()
            }
        }
        return clean
    }
    return [
        "data": [
            "team": [
                "id": "team-uuid",
                "name": "Engineering",
                "issues": ["nodes": nodes],
            ]
        ]
    ]
}

@Test func syncReturnsIssuesCorrectly() async throws {
    let responseJSON = teamResponseJSON(issues: [
        [
            "id": "issue-uuid-1",
            "identifier": "ENG-42",
            "title": "Implement feature",
            "dueDate": "2026-07-01",
            "completedAt": nil,
            "url": "https://linear.app/team/issue/ENG-42",
            "state": ["name": "In Progress", "color": "#00ff00"],
        ],
        [
            "id": "issue-uuid-2",
            "identifier": "ENG-43",
            "title": "Fix bug",
            "dueDate": "2026-07-02",
            "completedAt": nil,
            "url": "https://linear.app/team/issue/ENG-43",
            "state": ["name": "Todo", "color": nil],
        ],
    ])

    let session = URLSession.mocking([MockResponse(url: graphQLEndpoint, statusCode: 200, body: jsonData(responseJSON))])
    let service = LinearService(session: session)
    let day = DateComponents(calendar: .autoupdatingCurrent, year: 2026, month: 7, day: 1).date!

    let result = try await service.sync(day: day, settings: makeSettings(), apiKey: mockAPIKey)

    #expect(result.events.count == 2)
    #expect(result.events[0].title == "Implement feature")
    #expect(result.events[0].id == "linear-issue-uuid-1")
    #expect(result.events[1].title == "Fix bug")
}

@Test func syncThrowsMissingTokenWhenEmpty() async {
    let session = URLSession.mocking([])
    let service = LinearService(session: session)

    await #expect(throws: LinearIssue.missingToken) {
        try await service.sync(day: Date(), settings: makeSettings(), apiKey: "")
    }
}

@Test func syncThrowsMissingTeamsWhenEmpty() async {
    let session = URLSession.mocking([])
    let service = LinearService(session: session)
    let settings = makeSettings(teamIDs: [])

    await #expect(throws: LinearIssue.missingTeams) {
        try await service.sync(day: Date(), settings: settings, apiKey: mockAPIKey)
    }
}

@Test func syncThrowsUnauthorizedOn401() async {
    let session = URLSession.mocking([MockResponse(url: graphQLEndpoint, statusCode: 401, body: Data())])
    let service = LinearService(session: session)

    await #expect(throws: LinearIssue.unauthorized) {
        try await service.sync(day: Date(), settings: makeSettings(), apiKey: mockAPIKey)
    }
}

@Test func syncThrowsInvalidResponseOnMalformedJSON() async {
    let session = URLSession.mocking([MockResponse(url: graphQLEndpoint, statusCode: 200, body: Data("not json".utf8))])
    let service = LinearService(session: session)

    await #expect(throws: LinearIssue.invalidResponse) {
        try await service.sync(day: Date(), settings: makeSettings(), apiKey: mockAPIKey)
    }
}

@Test func syncExcludesItemsWithoutDueDate() async {
    let responseJSON = teamResponseJSON(issues: [
        [
            "id": "issue-uuid-1",
            "identifier": "ENG-42",
            "title": "Has due date",
            "dueDate": "2026-07-01",
            "completedAt": nil,
            "url": nil,
            "state": nil,
        ],
        [
            "id": "issue-uuid-2",
            "identifier": "ENG-43",
            "title": "No due date",
            "dueDate": nil,
            "completedAt": nil,
            "url": nil,
            "state": nil,
        ],
        [
            "id": "issue-uuid-3",
            "identifier": "ENG-44",
            "title": "Empty due date",
            "dueDate": "",
            "completedAt": nil,
            "url": nil,
            "state": nil,
        ],
    ])

    let session = URLSession.mocking([MockResponse(url: graphQLEndpoint, statusCode: 200, body: jsonData(responseJSON))])
    let service = LinearService(session: session)
    let day = DateComponents(calendar: .autoupdatingCurrent, year: 2026, month: 7, day: 1).date!

    let result = try await service.sync(day: day, settings: makeSettings(), apiKey: mockAPIKey)

    #expect(result.events.count == 1)
    #expect(result.events[0].title == "Has due date")
}

#elseif canImport(XCTest)
import XCTest
@testable import luum

final class LinearServiceTests: XCTestCase {
    struct MockResponse: Sendable {
        let url: String
        let statusCode: Int
        let body: Data
    }

    let mockAPIKey = "lin_api_key_123"

    final class MockURLProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var responses: [MockResponse] = []

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            defer { client?.urlProtocolDidFinishLoading(self) }
            guard let response = Self.responses.first else { return }
            Self.responses.removeFirst()
            guard let requestURL = request.url?.absoluteString, requestURL == response.url else { return }
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.body)
        }

        override func stopLoading() {}
    }

    func urlSessionMocking(_ responses: [MockResponse]) -> URLSession {
        MockURLProtocol.responses = responses
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func makeSettings(teamIDs: [String] = ["TEAM"]) -> LinearSettings {
        LinearSettings(
            isEnabled: true,
            workspaceLabel: "MyTeam",
            workspaceID: "ws_1",
            teamIDs: teamIDs,
            includeCompletedIssues: false,
            lastSyncAt: nil
        )
    }

    let graphQLEndpoint = "https://api.linear.app/graphql"

    func jsonData(_ value: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    }

    func teamResponseJSON(issues: [[String: Any?]]) -> [String: Any] {
        let nodes: [Any] = issues.map { issue in
            var clean: [String: Any] = [:]
            for (key, val) in issue {
                if let val {
                    clean[key] = val
                } else {
                    clean[key] = NSNull()
                }
            }
            return clean
        }
        return [
            "data": [
                "team": [
                    "id": "team-uuid",
                    "name": "Engineering",
                    "issues": ["nodes": nodes],
                ]
            ]
        ]
    }

    func testSyncReturnsIssuesCorrectly() async throws {
        let responseJSON = teamResponseJSON(issues: [
            [
                "id": "issue-uuid-1",
                "identifier": "ENG-42",
                "title": "Implement feature",
                "dueDate": "2026-07-01",
                "completedAt": nil as Any?,
                "url": "https://linear.app/team/issue/ENG-42",
                "state": ["name": "In Progress", "color": "#00ff00"],
            ],
            [
                "id": "issue-uuid-2",
                "identifier": "ENG-43",
                "title": "Fix bug",
                "dueDate": "2026-07-02",
                "completedAt": nil as Any?,
                "url": "https://linear.app/team/issue/ENG-43",
                "state": ["name": "Todo", "color": nil as Any?],
            ],
        ])

        let session = urlSessionMocking([MockResponse(url: graphQLEndpoint, statusCode: 200, body: jsonData(responseJSON))])
        let service = LinearService(session: session)
        let day = DateComponents(calendar: .autoupdatingCurrent, year: 2026, month: 7, day: 1).date!

        let result = try await service.sync(day: day, settings: makeSettings(), apiKey: mockAPIKey)

        XCTAssertEqual(result.events.count, 2)
        XCTAssertEqual(result.events[0].title, "Implement feature")
        XCTAssertEqual(result.events[0].id, "linear-issue-uuid-1")
        XCTAssertEqual(result.events[1].title, "Fix bug")
    }

    func testSyncThrowsMissingTokenWhenEmpty() async throws {
        let session = urlSessionMocking([])
        let service = LinearService(session: session)

        do {
            try await service.sync(day: Date(), settings: makeSettings(), apiKey: "")
            XCTFail("Expected missingToken error")
        } catch let error as LinearIssue {
            XCTAssertEqual(error, .missingToken)
        }
    }

    func testSyncThrowsMissingTeamsWhenEmpty() async throws {
        let session = urlSessionMocking([])
        let service = LinearService(session: session)
        let settings = makeSettings(teamIDs: [])

        do {
            try await service.sync(day: Date(), settings: settings, apiKey: mockAPIKey)
            XCTFail("Expected missingTeams error")
        } catch let error as LinearIssue {
            XCTAssertEqual(error, .missingTeams)
        }
    }

    func testSyncThrowsUnauthorizedOn401() async throws {
        let session = urlSessionMocking([MockResponse(url: graphQLEndpoint, statusCode: 401, body: Data())])
        let service = LinearService(session: session)

        do {
            try await service.sync(day: Date(), settings: makeSettings(), apiKey: mockAPIKey)
            XCTFail("Expected unauthorized error")
        } catch let error as LinearIssue {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func testSyncThrowsInvalidResponseOnMalformedJSON() async throws {
        let session = urlSessionMocking([MockResponse(url: graphQLEndpoint, statusCode: 200, body: Data("not json".utf8))])
        let service = LinearService(session: session)

        do {
            try await service.sync(day: Date(), settings: makeSettings(), apiKey: mockAPIKey)
            XCTFail("Expected invalidResponse error")
        } catch let error as LinearIssue {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testSyncExcludesItemsWithoutDueDate() async throws {
        let responseJSON = teamResponseJSON(issues: [
            [
                "id": "issue-uuid-1",
                "identifier": "ENG-42",
                "title": "Has due date",
                "dueDate": "2026-07-01",
                "completedAt": nil as Any?,
                "url": nil as Any?,
                "state": nil as Any?,
            ],
            [
                "id": "issue-uuid-2",
                "identifier": "ENG-43",
                "title": "No due date",
                "dueDate": nil as Any?,
                "completedAt": nil as Any?,
                "url": nil as Any?,
                "state": nil as Any?,
            ],
            [
                "id": "issue-uuid-3",
                "identifier": "ENG-44",
                "title": "Empty due date",
                "dueDate": "",
                "completedAt": nil as Any?,
                "url": nil as Any?,
                "state": nil as Any?,
            ],
        ])

        let session = urlSessionMocking([MockResponse(url: graphQLEndpoint, statusCode: 200, body: jsonData(responseJSON))])
        let service = LinearService(session: session)
        let day = DateComponents(calendar: .autoupdatingCurrent, year: 2026, month: 7, day: 1).date!

        let result = try await service.sync(day: day, settings: makeSettings(), apiKey: mockAPIKey)

        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events[0].title, "Has due date")
    }
}
#endif
