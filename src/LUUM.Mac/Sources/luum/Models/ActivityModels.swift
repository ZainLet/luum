import Foundation

enum CategoryColorToken: String, Codable, CaseIterable, Identifiable, Sendable {
    case sky
    case magenta
    case mint
    case amber
    case silver
    case violet
    case coral
    case teal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sky:
            "Sky"
        case .magenta:
            "Magenta"
        case .mint:
            "Mint"
        case .amber:
            "Amber"
        case .silver:
            "Silver"
        case .violet:
            "Violet"
        case .coral:
            "Coral"
        case .teal:
            "Teal"
        }
    }
}

struct ActivityCategory: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var title: String
    var systemImage: String
    var colorToken: CategoryColorToken
    var isBuiltIn: Bool

    init(
        id: String,
        title: String,
        systemImage: String,
        colorToken: CategoryColorToken,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.colorToken = colorToken
        self.isBuiltIn = isBuiltIn
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case systemImage
        case colorToken
        case isBuiltIn
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let rawValue = try? container.decode(String.self),
           let builtIn = Self.builtInMap[rawValue] {
            self = builtIn
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        systemImage = try container.decode(String.self, forKey: .systemImage)
        colorToken = try container.decode(CategoryColorToken.self, forKey: .colorToken)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(systemImage, forKey: .systemImage)
        try container.encode(colorToken, forKey: .colorToken)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
    }

    static let work = ActivityCategory(
        id: "work",
        title: "Trabalho",
        systemImage: "briefcase.fill",
        colorToken: .sky,
        isBuiltIn: true
    )

    static let entertainment = ActivityCategory(
        id: "entertainment",
        title: "Entretenimento",
        systemImage: "play.tv.fill",
        colorToken: .magenta,
        isBuiltIn: true
    )

    static let communication = ActivityCategory(
        id: "communication",
        title: "Comunicação",
        systemImage: "bubble.left.and.bubble.right.fill",
        colorToken: .mint,
        isBuiltIn: true
    )

    static let learning = ActivityCategory(
        id: "learning",
        title: "Aprendizado",
        systemImage: "book.closed.fill",
        colorToken: .amber,
        isBuiltIn: true
    )

    static let utilities = ActivityCategory(
        id: "utilities",
        title: "Utilitarios",
        systemImage: "slider.horizontal.3",
        colorToken: .silver,
        isBuiltIn: true
    )

    static let uncategorized = ActivityCategory(
        id: "uncategorized",
        title: "Sem categoria",
        systemImage: "sparkle.magnifyingglass",
        colorToken: .violet,
        isBuiltIn: true
    )

    static let builtInCategories = [
        work,
        entertainment,
        communication,
        learning,
        utilities,
        uncategorized,
    ]

    static let builtInMap = Dictionary(uniqueKeysWithValues: builtInCategories.map { ($0.id, $0) })
}

enum ActivitySource: String, Codable, Sendable {
    case nativeApp
    case browserURL
}

struct ActivitySnapshot: Equatable, Sendable {
    let timestamp: Date
    let applicationName: String
    let bundleIdentifier: String?
    let webURL: String?
    let pageTitle: String?
}

struct ActivitySample: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var startDate: Date
    var endDate: Date
    var applicationName: String
    var bundleIdentifier: String?
    var webURL: String?
    var webDomain: String?
    var pageTitle: String?
    var source: ActivitySource
    var manualCategoryID: String?
    var isHidden: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        applicationName: String,
        bundleIdentifier: String?,
        webURL: String?,
        webDomain: String?,
        pageTitle: String?,
        source: ActivitySource,
        manualCategoryID: String? = nil,
        isHidden: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.webURL = webURL
        self.webDomain = webDomain
        self.pageTitle = pageTitle
        self.source = source
        self.manualCategoryID = manualCategoryID
        self.isHidden = isHidden
        self.note = note
    }

    init(snapshot: ActivitySnapshot, domain: String?, sanitizedURL: String?, sanitizedTitle: String?) {
        self.init(
            startDate: snapshot.timestamp,
            endDate: snapshot.timestamp,
            applicationName: snapshot.applicationName,
            bundleIdentifier: snapshot.bundleIdentifier,
            webURL: sanitizedURL,
            webDomain: domain,
            pageTitle: sanitizedTitle,
            source: snapshot.webURL == nil ? .nativeApp : .browserURL
        )
    }

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    func canExtend(with snapshot: ActivitySnapshot, maximumGap: TimeInterval, sanitizedURL: String?, sanitizedTitle: String?) -> Bool {
        matchesIdentity(snapshot, sanitizedURL: sanitizedURL, sanitizedTitle: sanitizedTitle) &&
        snapshot.timestamp.timeIntervalSince(endDate) <= maximumGap
    }

    private func matchesIdentity(_ snapshot: ActivitySnapshot, sanitizedURL: String?, sanitizedTitle: String?) -> Bool {
        applicationName == snapshot.applicationName &&
        bundleIdentifier == snapshot.bundleIdentifier &&
        webURL == sanitizedURL &&
        pageTitle == sanitizedTitle
    }
}

struct ResolvedActivitySample: Identifiable, Hashable {
    let sample: ActivitySample
    let category: ActivityCategory

    var id: UUID { sample.id }
    var startDate: Date { sample.startDate }
    var endDate: Date { sample.endDate }
    var applicationName: String { sample.applicationName }
    var bundleIdentifier: String? { sample.bundleIdentifier }
    var webURL: String? { sample.webURL }
    var webDomain: String? { sample.webDomain }
    var pageTitle: String? { sample.pageTitle }
    var duration: TimeInterval { sample.duration }
    var isManuallyCategorized: Bool { sample.manualCategoryID != nil }
    var note: String? { sample.note }
}

struct CategoryBreakdown: Identifiable, Hashable {
    let category: ActivityCategory
    let duration: TimeInterval

    var id: String { category.id }
    var hours: Double { duration / 3600 }
}

struct UsageBreakdownItem: Identifiable, Hashable {
    let id: String
    let label: String
    let secondaryLabel: String?
    let duration: TimeInterval
    let category: ActivityCategory?
    let systemImage: String
}

struct RulePreview: Identifiable, Hashable {
    let id: String
    let category: ActivityCategory
    let examples: [String]
}

struct DailySummary {
    let day: Date
    let totalTrackedTime: TimeInterval
    let categoryBreakdown: [CategoryBreakdown]
    let appBreakdown: [UsageBreakdownItem]
    let websiteBreakdown: [UsageBreakdownItem]
    let timelineActivities: [ResolvedActivitySample]
    let recentActivities: [ResolvedActivitySample]

    static func empty(for day: Date) -> DailySummary {
        DailySummary(
            day: day,
            totalTrackedTime: 0,
            categoryBreakdown: [],
            appBreakdown: [],
            websiteBreakdown: [],
            timelineActivities: [],
            recentActivities: []
        )
    }
}
