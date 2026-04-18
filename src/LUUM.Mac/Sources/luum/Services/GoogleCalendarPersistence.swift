import Foundation

struct GoogleCalendarPersistence {
    private let fileManager: FileManager
    private let directoryName = "luum"
    private let fileName = "google-calendar.json"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load() -> GoogleCalendarSnapshot {
        guard
            let data = try? Data(contentsOf: fileURL),
            let snapshot = try? JSONDecoder().decode(GoogleCalendarSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }

    func save(snapshot: GoogleCalendarSnapshot) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    private var directoryURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }
}
