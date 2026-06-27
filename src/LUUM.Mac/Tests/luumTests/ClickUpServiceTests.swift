import Foundation
#if canImport(Testing)
import Testing
@testable import luum

private struct MockResponse: Sendable {
    let url: String
    let statusCode: Int
    let body: Data
}

private let mockAPIToken = "cup_api_token_123"

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

private func makeSettings(listIDs: [String] = ["LIST"]) -> ClickUpSettings {
    ClickUpSettings(
        isEnabled: true,
        workspaceLabel: "MyWorkspace",
        workspaceID: "ws_1",
        listIDs: listIDs,
        includeClosedTasks: false,
        lastSyncAt: nil
    )
}

private func jsonData(_ value: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
}

private let tasksEndpointPrefix = "https://api.clickup.com/api/v2/list/"

private func tasksEndpoint(for listID: String) -> String {
    "\(tasksEndpointPrefix)\(listID)/task"
}

private func tasksResponseJSON(tasks: [[String: Any?]]) -> [String: Any] {
    let nodes: [Any] = tasks.map { task in
        var clean: [String: Any] = [:]
        for (key, val) in task {
            if let val {
                clean[key] = val
            } else {
                clean[key] = NSNull()
            }
        }
        return clean
    }
    return ["tasks": nodes]
}

@Test func syncReturnsTasksWithDueDate() async throws {
    let dueDateMS = "1769827200000"
    let tasksJSON = tasksResponseJSON(tasks: [
        [
            "id": "task-uuid-1",
            "name": "Design homepage",
            "description": "Create wireframes",
            "url": "https://app.clickup.com/t/task-uuid-1",
            "due_date": dueDateMS,
            "start_date": NSNull(),
            "list": ["id": "list-1", "name": "Design"],
            "status": ["color": "#ff0000"],
        ],
        [
            "id": "task-uuid-2",
            "name": "Implement API",
            "description": nil,
            "url": nil,
            "due_date": dueDateMS,
            "start_date": dueDateMS,
            "list": ["id": "list-1", "name": "Design"],
            "status": nil,
        ],
    ])

    let session = URLSession.mocking([MockResponse(url: tasksEndpoint(for: "LIST"), statusCode: 200, body: jsonData(tasksJSON))])
    let service = ClickUpService(session: session)
    let day = Date(timeIntervalSince1970: 1_769_827_200)

    let result = try await service.sync(day: day, settings: makeSettings(), apiToken: mockAPIToken)

    #expect(result.events.count == 2)
    #expect(result.events[0].title == "Design homepage")
    #expect(result.events[0].id == "clickup-task-uuid-1")
    #expect(result.events[1].title == "Implement API")
}

@Test func syncThrowsMissingTokenWhenEmpty() async {
    let session = URLSession.mocking([])
    let service = ClickUpService(session: session)

    await #expect(throws: ClickUpIssue.missingToken) {
        try await service.sync(day: Date(), settings: makeSettings(), apiToken: "")
    }
}

@Test func syncThrowsMissingListsWhenEmpty() async {
    let session = URLSession.mocking([])
    let service = ClickUpService(session: session)
    let settings = makeSettings(listIDs: [])

    await #expect(throws: ClickUpIssue.missingLists) {
        try await service.sync(day: Date(), settings: settings, apiToken: mockAPIToken)
    }
}

@Test func syncThrowsUnauthorizedOn401() async {
    let session = URLSession.mocking([MockResponse(url: tasksEndpoint(for: "LIST"), statusCode: 401, body: Data())])
    let service = ClickUpService(session: session)

    await #expect(throws: ClickUpIssue.unauthorized) {
        try await service.sync(day: Date(), settings: makeSettings(), apiToken: mockAPIToken)
    }
}

@Test func syncThrowsInvalidResponseOnMalformedJSON() async {
    let session = URLSession.mocking([MockResponse(url: tasksEndpoint(for: "LIST"), statusCode: 200, body: Data("not json".utf8))])
    let service = ClickUpService(session: session)

    await #expect(throws: ClickUpIssue.invalidResponse) {
        try await service.sync(day: Date(), settings: makeSettings(), apiToken: mockAPIToken)
    }
}

@Test func syncExcludesTasksWithoutDueDate() async {
    let tasksJSON = tasksResponseJSON(tasks: [
        [
            "id": "task-uuid-1",
            "name": "Has due date",
            "description": nil,
            "url": nil,
            "due_date": "1769827200000",
            "start_date": NSNull(),
            "list": nil,
            "status": nil,
        ],
        [
            "id": "task-uuid-2",
            "name": "No due date",
            "description": nil,
            "url": nil,
            "due_date": nil,
            "start_date": NSNull(),
            "list": nil,
            "status": nil,
        ],
        [
            "id": "task-uuid-3",
            "name": "Empty due date",
            "description": nil,
            "url": nil,
            "due_date": "",
            "start_date": NSNull(),
            "list": nil,
            "status": nil,
        ],
    ])

    let session = URLSession.mocking([MockResponse(url: tasksEndpoint(for: "LIST"), statusCode: 200, body: jsonData(tasksJSON))])
    let service = ClickUpService(session: session)
    let day = Date(timeIntervalSince1970: 1_769_827_200)

    let result = try await service.sync(day: day, settings: makeSettings(), apiToken: mockAPIToken)

    #expect(result.events.count == 1)
    #expect(result.events[0].title == "Has due date")
}

#elseif canImport(XCTest)
import XCTest
@testable import luum

final class ClickUpServiceTests: XCTestCase {
    struct MockResponse: Sendable {
        let url: String
        let statusCode: Int
        let body: Data
    }

    let mockAPIToken = "cup_api_token_123"

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

    func makeSettings(listIDs: [String] = ["LIST"]) -> ClickUpSettings {
        ClickUpSettings(
            isEnabled: true,
            workspaceLabel: "MyWorkspace",
            workspaceID: "ws_1",
            listIDs: listIDs,
            includeClosedTasks: false,
            lastSyncAt: nil
        )
    }

    func jsonData(_ value: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    }

    let tasksEndpointPrefix = "https://api.clickup.com/api/v2/list/"

    func tasksEndpoint(for listID: String) -> String {
        "\(tasksEndpointPrefix)\(listID)/task"
    }

    func tasksResponseJSON(tasks: [[String: Any?]]) -> [String: Any] {
        let nodes: [Any] = tasks.map { task in
            var clean: [String: Any] = [:]
            for (key, val) in task {
                if let val {
                    clean[key] = val
                } else {
                    clean[key] = NSNull()
                }
            }
            return clean
        }
        return ["tasks": nodes]
    }

    func testSyncReturnsTasksWithDueDate() async throws {
        let dueDateMS = "1769827200000"
        let tasksJSON = tasksResponseJSON(tasks: [
            [
                "id": "task-uuid-1",
                "name": "Design homepage",
                "description": "Create wireframes",
                "url": "https://app.clickup.com/t/task-uuid-1",
                "due_date": dueDateMS,
                "start_date": nil as Any?,
                "list": ["id": "list-1", "name": "Design"],
                "status": ["color": "#ff0000"],
            ],
            [
                "id": "task-uuid-2",
                "name": "Implement API",
                "description": nil as Any?,
                "url": nil as Any?,
                "due_date": dueDateMS,
                "start_date": dueDateMS,
                "list": ["id": "list-1", "name": "Design"],
                "status": nil as Any?,
            ],
        ])

        let session = urlSessionMocking([MockResponse(url: tasksEndpoint(for: "LIST"), statusCode: 200, body: jsonData(tasksJSON))])
        let service = ClickUpService(session: session)
        let day = Date(timeIntervalSince1970: 1_769_827_200)

        let result = try await service.sync(day: day, settings: makeSettings(), apiToken: mockAPIToken)

        XCTAssertEqual(result.events.count, 2)
        XCTAssertEqual(result.events[0].title, "Design homepage")
        XCTAssertEqual(result.events[0].id, "clickup-task-uuid-1")
        XCTAssertEqual(result.events[1].title, "Implement API")
    }

    func testSyncThrowsMissingTokenWhenEmpty() async throws {
        let session = urlSessionMocking([])
        let service = ClickUpService(session: session)

        do {
            try await service.sync(day: Date(), settings: makeSettings(), apiToken: "")
            XCTFail("Expected missingToken error")
        } catch let error as ClickUpIssue {
            XCTAssertEqual(error, .missingToken)
        }
    }

    func testSyncThrowsMissingListsWhenEmpty() async throws {
        let session = urlSessionMocking([])
        let service = ClickUpService(session: session)
        let settings = makeSettings(listIDs: [])

        do {
            try await service.sync(day: Date(), settings: settings, apiToken: mockAPIToken)
            XCTFail("Expected missingLists error")
        } catch let error as ClickUpIssue {
            XCTAssertEqual(error, .missingLists)
        }
    }

    func testSyncThrowsUnauthorizedOn401() async throws {
        let session = urlSessionMocking([MockResponse(url: tasksEndpoint(for: "LIST"), statusCode: 401, body: Data())])
        let service = ClickUpService(session: session)

        do {
            try await service.sync(day: Date(), settings: makeSettings(), apiToken: mockAPIToken)
            XCTFail("Expected unauthorized error")
        } catch let error as ClickUpIssue {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func testSyncThrowsInvalidResponseOnMalformedJSON() async throws {
        let session = urlSessionMocking([MockResponse(url: tasksEndpoint(for: "LIST"), statusCode: 200, body: Data("not json".utf8))])
        let service = ClickUpService(session: session)

        do {
            try await service.sync(day: Date(), settings: makeSettings(), apiToken: mockAPIToken)
            XCTFail("Expected invalidResponse error")
        } catch let error as ClickUpIssue {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testSyncExcludesTasksWithoutDueDate() async throws {
        let tasksJSON = tasksResponseJSON(tasks: [
            [
                "id": "task-uuid-1",
                "name": "Has due date",
                "description": nil as Any?,
                "url": nil as Any?,
                "due_date": "1769827200000",
                "start_date": nil as Any?,
                "list": nil as Any?,
                "status": nil as Any?,
            ],
            [
                "id": "task-uuid-2",
                "name": "No due date",
                "description": nil as Any?,
                "url": nil as Any?,
                "due_date": nil as Any?,
                "start_date": nil as Any?,
                "list": nil as Any?,
                "status": nil as Any?,
            ],
            [
                "id": "task-uuid-3",
                "name": "Empty due date",
                "description": nil as Any?,
                "url": nil as Any?,
                "due_date": "",
                "start_date": nil as Any?,
                "list": nil as Any?,
                "status": nil as Any?,
            ],
        ])

        let session = urlSessionMocking([MockResponse(url: tasksEndpoint(for: "LIST"), statusCode: 200, body: jsonData(tasksJSON))])
        let service = ClickUpService(session: session)
        let day = Date(timeIntervalSince1970: 1_769_827_200)

        let result = try await service.sync(day: day, settings: makeSettings(), apiToken: mockAPIToken)

        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events[0].title, "Has due date")
    }
}
#endif
