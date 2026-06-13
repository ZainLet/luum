import Foundation

struct MonitoringPreferencesPersistence: @unchecked Sendable {
    private let fileManager: FileManager
    // All FileManager and JSON file access is serialized through this queue.
    private let ioQueue = DispatchQueue(label: "com.luum.monitoring-preferences.persistence")
    private let directoryName = "luum"
    private let fileName = "monitoring-preferences.json"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load() -> MonitoringPreferencesSnapshot {
        ioQueue.sync {
            guard
                let data = try? Data(contentsOf: fileURL),
                let snapshot = try? JSONDecoder().decode(MonitoringPreferencesSnapshot.self, from: data)
            else {
                return MonitoringPreferencesSnapshot.default.normalized()
            }

            return snapshot.normalized()
        }
    }

    func save(snapshot: MonitoringPreferencesSnapshot) throws {
        try ioQueue.sync {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let data = try JSONEncoder().encode(snapshot.normalized())
            try data.write(to: fileURL, options: .atomic)
        }
    }

    private var directoryURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }
}
