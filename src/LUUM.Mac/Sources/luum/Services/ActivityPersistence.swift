import Foundation

struct ActivityPersistence: @unchecked Sendable {
    private let fileManager: FileManager
    private let directoryName = "luum"
    private let fileName = "activity-log.json"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load(retentionDays: Int = 30) -> [ActivitySample] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let samples = try? JSONDecoder().decode([ActivitySample].self, from: data)
        else {
            return []
        }

        return trim(samples: samples, retentionDays: retentionDays)
    }

    func save(samples: [ActivitySample], retentionDays: Int = 30) throws {
        let cleanedSamples = trim(samples: samples, retentionDays: retentionDays)

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(cleanedSamples)
        try data.write(to: fileURL, options: .atomic)
    }

    func trim(samples: [ActivitySample], retentionDays: Int = 30) -> [ActivitySample] {
        let cutoff = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        return samples.filter { $0.endDate >= cutoff }
    }

    private var directoryURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }
}
