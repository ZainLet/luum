import Foundation

enum ActivityCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case work
    case entertainment
    case communication
    case learning
    case utilities
    case uncategorized

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work:
            "Trabalho"
        case .entertainment:
            "Entretenimento"
        case .communication:
            "Comunicacao"
        case .learning:
            "Aprendizado"
        case .utilities:
            "Utilitarios"
        case .uncategorized:
            "Sem categoria"
        }
    }

    var systemImage: String {
        switch self {
        case .work:
            "briefcase.fill"
        case .entertainment:
            "play.tv.fill"
        case .communication:
            "bubble.left.and.bubble.right.fill"
        case .learning:
            "book.closed.fill"
        case .utilities:
            "slider.horizontal.3"
        case .uncategorized:
            "sparkle.magnifyingglass"
        }
    }
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
    let category: ActivityCategory
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
    var category: ActivityCategory
    var source: ActivitySource

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        applicationName: String,
        bundleIdentifier: String?,
        webURL: String?,
        webDomain: String?,
        pageTitle: String?,
        category: ActivityCategory,
        source: ActivitySource
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.webURL = webURL
        self.webDomain = webDomain
        self.pageTitle = pageTitle
        self.category = category
        self.source = source
    }

    init(snapshot: ActivitySnapshot, domain: String?) {
        self.init(
            startDate: snapshot.timestamp,
            endDate: snapshot.timestamp,
            applicationName: snapshot.applicationName,
            bundleIdentifier: snapshot.bundleIdentifier,
            webURL: snapshot.webURL,
            webDomain: domain,
            pageTitle: snapshot.pageTitle,
            category: snapshot.category,
            source: snapshot.webURL == nil ? .nativeApp : .browserURL
        )
    }

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    func canExtend(with snapshot: ActivitySnapshot, maximumGap: TimeInterval) -> Bool {
        matchesIdentity(snapshot) && snapshot.timestamp.timeIntervalSince(endDate) <= maximumGap
    }

    private func matchesIdentity(_ snapshot: ActivitySnapshot) -> Bool {
        applicationName == snapshot.applicationName &&
        bundleIdentifier == snapshot.bundleIdentifier &&
        webURL == snapshot.webURL &&
        pageTitle == snapshot.pageTitle &&
        category == snapshot.category
    }
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
    let timelineActivities: [ActivitySample]
    let recentActivities: [ActivitySample]

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
