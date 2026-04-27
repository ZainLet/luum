import Foundation

struct ClassificationEngine {
    static let defaultRules: [CategoryRule] = [
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "github.com"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "gitlab.com"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "linear.app"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "notion.so"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "notion.site"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "figma.com"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "vercel.com"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "atlassian.net"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "docs.google.com"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "drive.google.com"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .domain, pattern: "openai.com"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .domain, pattern: "youtube.com"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .domain, pattern: "netflix.com"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .domain, pattern: "twitch.tv"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .domain, pattern: "spotify.com"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .domain, pattern: "disneyplus.com"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .domain, pattern: "primevideo.com"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .domain, pattern: "max.com"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .domain, pattern: "crunchyroll.com"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .domain, pattern: "slack.com"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .domain, pattern: "discord.com"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .domain, pattern: "teams.microsoft.com"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .domain, pattern: "meet.google.com"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .domain, pattern: "web.whatsapp.com"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .domain, pattern: "mail.google.com"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .domain, pattern: "telegram.org"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .domain, pattern: "developer.apple.com"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .domain, pattern: "docs.swift.org"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .domain, pattern: "learn.microsoft.com"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .domain, pattern: "developer.mozilla.org"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .domain, pattern: "coursera.org"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .domain, pattern: "udemy.com"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .domain, pattern: "stackoverflow.com"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .domain, pattern: "freecodecamp.org"),
        CategoryRule(categoryID: ActivityCategory.utilities.id, matchTarget: .domain, pattern: "calendar.google.com"),
        CategoryRule(categoryID: ActivityCategory.utilities.id, matchTarget: .domain, pattern: "keep.google.com"),
        CategoryRule(categoryID: ActivityCategory.utilities.id, matchTarget: .domain, pattern: "todoist.com"),
        CategoryRule(categoryID: ActivityCategory.utilities.id, matchTarget: .domain, pattern: "icloud.com"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "xcode"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "visual studio code"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "cursor"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "terminal"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "warp"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "iterm"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "figma"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "docker"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "postman"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "tableplus"),
        CategoryRule(categoryID: ActivityCategory.work.id, matchTarget: .applicationName, pattern: "simulator"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .applicationName, pattern: "music"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .applicationName, pattern: "spotify"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .applicationName, pattern: "tv"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .applicationName, pattern: "steam"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .applicationName, pattern: "vlc"),
        CategoryRule(categoryID: ActivityCategory.entertainment.id, matchTarget: .applicationName, pattern: "iina"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .applicationName, pattern: "slack"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .applicationName, pattern: "discord"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .applicationName, pattern: "zoom"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .applicationName, pattern: "teams"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .applicationName, pattern: "mail"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .applicationName, pattern: "messages"),
        CategoryRule(categoryID: ActivityCategory.communication.id, matchTarget: .applicationName, pattern: "telegram"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .applicationName, pattern: "books"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .applicationName, pattern: "kindle"),
        CategoryRule(categoryID: ActivityCategory.learning.id, matchTarget: .applicationName, pattern: "obsidian"),
        CategoryRule(categoryID: ActivityCategory.utilities.id, matchTarget: .applicationName, pattern: "finder"),
        CategoryRule(categoryID: ActivityCategory.utilities.id, matchTarget: .applicationName, pattern: "preview"),
        CategoryRule(categoryID: ActivityCategory.utilities.id, matchTarget: .applicationName, pattern: "system settings"),
        CategoryRule(categoryID: ActivityCategory.utilities.id, matchTarget: .applicationName, pattern: "calendar"),
        CategoryRule(categoryID: ActivityCategory.utilities.id, matchTarget: .applicationName, pattern: "notes"),
    ]

    func classify(
        applicationName: String,
        bundleIdentifier: String?,
        webURL: String?,
        preferences: MonitoringPreferencesSnapshot
    ) -> ActivityCategory {
        for rule in preferences.categoryRules {
            guard let category = preferences.category(for: rule.categoryID) else {
                continue
            }

            if matches(
                rule: rule,
                applicationName: applicationName,
                bundleIdentifier: bundleIdentifier,
                webURL: webURL
            ) {
                return category
            }
        }

        return preferences.category(for: ActivityCategory.uncategorized.id) ?? .uncategorized
    }

    func classify(sample: ActivitySample, preferences: MonitoringPreferencesSnapshot) -> ActivityCategory {
        classify(
            applicationName: sample.applicationName,
            bundleIdentifier: sample.bundleIdentifier,
            webURL: sample.webURL,
            preferences: preferences
        )
    }

    func isIgnored(
        applicationName: String,
        bundleIdentifier: String?,
        webURL: String?,
        preferences: MonitoringPreferencesSnapshot
    ) -> Bool {
        let appFingerprint = [applicationName, bundleIdentifier ?? ""]
            .joined(separator: " ")
            .lowercased()
        let domain = domain(from: webURL)

        if preferences.ignoredApplications.contains(where: { normalizedPattern in
            appFingerprint.contains(normalizedPattern)
        }) {
            return true
        }

        if let domain,
           preferences.ignoredDomains.contains(where: { normalizedPattern in
               domain == normalizedPattern || domain.hasSuffix(".\(normalizedPattern)")
           }) {
            return true
        }

        return false
    }

    func previewRules(from preferences: MonitoringPreferencesSnapshot) -> [RulePreview] {
        preferences.categories.compactMap { category in
            let examples = preferences.categoryRules
                .filter { $0.categoryID == category.id }
                .map(\.pattern)
                .prefix(5)
                .map { $0 }

            guard !examples.isEmpty else { return nil }
            return RulePreview(id: category.id, category: category, examples: examples)
        }
    }

    func domain(from webURL: String?) -> String? {
        guard
            let webURL,
            let components = URLComponents(string: webURL),
            let host = components.host?.lowercased()
        else {
            return nil
        }

        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private func matches(
        rule: CategoryRule,
        applicationName: String,
        bundleIdentifier: String?,
        webURL: String?
    ) -> Bool {
        let normalizedPattern = normalized(rule.pattern)
        guard !normalizedPattern.isEmpty else { return false }

        switch rule.matchTarget {
        case .applicationName:
            return normalized(applicationName).contains(normalizedPattern)
        case .bundleIdentifier:
            return normalized(bundleIdentifier ?? "").contains(normalizedPattern)
        case .domain:
            guard let domain = domain(from: webURL) else { return false }
            return domain == normalizedPattern || domain.hasSuffix(".\(normalizedPattern)")
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
