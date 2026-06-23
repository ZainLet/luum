import Foundation

// Escrito uma vez no init (main thread) antes de qualquer handler ser instalado.
nonisolated(unsafe) private var _crashQueueURL: URL?

struct CrashReport: Codable {
    let errorType: String
    let exceptionName: String?
    let stack: String?
    let signal: String?
    let message: String?
    let timestamp: Date

    init(errorType: String, exceptionName: String? = nil, stack: String? = nil,
         signal: String? = nil, message: String? = nil) {
        self.errorType = errorType
        self.exceptionName = exceptionName
        self.stack = stack
        self.signal = signal
        self.message = message
        self.timestamp = Date()
    }
}

// Installs signal/exception handlers, persists crash payloads locally,
// and uploads them on the next launch when the user is authenticated.
@MainActor
final class CrashReportService {
    private let queueURL: URL
    private let endpoint = URL(string: "https://luum-app.vercel.app/api/crash-report")!
    private static let shared = CrashReportService()

    static func install() { shared.installHandlers() }

    static func sendPending(idToken: String) async {
        await shared.uploadPending(idToken: idToken)
    }

    static func sendFeedback(message: String, idToken: String) async throws {
        try await shared.upload(
            CrashReport(errorType: "manual_feedback", message: message),
            idToken: idToken
        )
    }

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("luum", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        queueURL = dir.appendingPathComponent("crash-queue.json")
        _crashQueueURL = queueURL
    }

    private func installHandlers() {
        NSSetUncaughtExceptionHandler { exception in
            guard let url = _crashQueueURL else { return }
            CrashReportService.persist(
                CrashReport(
                    errorType: "NSException",
                    exceptionName: exception.name.rawValue,
                    stack: exception.callStackSymbols.prefix(40).joined(separator: "\n"),
                    message: exception.reason
                ),
                to: url
            )
        }
        for sig in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP] {
            signal(sig) { caught in
                if let url = _crashQueueURL {
                    CrashReportService.persist(
                        CrashReport(errorType: "signal", signal: String(caught)),
                        to: url
                    )
                }
                signal(caught, SIG_DFL)
                raise(caught)
            }
        }
    }

    private func uploadPending(idToken: String) async {
        guard let queue = loadQueue(), !queue.isEmpty else { return }
        var remaining: [CrashReport] = []
        for report in queue {
            do { try await upload(report, idToken: idToken) }
            catch { remaining.append(report) }
        }
        remaining.isEmpty
            ? (try? FileManager.default.removeItem(at: queueURL))
            : saveQueue(remaining)
    }

    private func upload(_ report: CrashReport, idToken: String) async throws {
        let info = Bundle.main.infoDictionary ?? [:]
        var payload: [String: Any] = [
            "appVersion": info["CFBundleShortVersionString"] as? String ?? "?",
            "build": info["CFBundleVersion"] as? String ?? "?",
            "macOSVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "errorType": report.errorType,
        ]
        if let v = report.exceptionName { payload["exceptionName"] = v }
        if let v = report.stack         { payload["stack"] = v }
        if let v = report.signal        { payload["signal"] = v }
        if let v = report.message       { payload["message"] = v }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }

    private func loadQueue() -> [CrashReport]? {
        guard let data = try? Data(contentsOf: queueURL) else { return nil }
        return try? JSONDecoder().decode([CrashReport].self, from: data)
    }

    private func saveQueue(_ reports: [CrashReport]) {
        guard let data = try? JSONEncoder().encode(reports) else { return }
        try? data.write(to: queueURL, options: .atomic)
    }

    // nonisolated — chamado de signal handlers fora da main thread
    nonisolated static func persist(_ report: CrashReport, to url: URL) {
        var queue: [CrashReport] = []
        if let data = try? Data(contentsOf: url) {
            queue = (try? JSONDecoder().decode([CrashReport].self, from: data)) ?? []
        }
        queue.append(report)
        if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
