import Foundation

struct ClassificationEngine {
    private let workDomains = [
        "github.com", "gitlab.com", "linear.app", "notion.so", "notion.site",
        "figma.com", "vercel.com", "atlassian.net", "docs.google.com",
        "drive.google.com", "openai.com"
    ]

    private let entertainmentDomains = [
        "youtube.com", "netflix.com", "twitch.tv", "spotify.com",
        "disneyplus.com", "primevideo.com", "max.com", "crunchyroll.com"
    ]

    private let communicationDomains = [
        "slack.com", "discord.com", "teams.microsoft.com", "meet.google.com",
        "web.whatsapp.com", "mail.google.com", "telegram.org"
    ]

    private let learningDomains = [
        "developer.apple.com", "docs.swift.org", "learn.microsoft.com",
        "developer.mozilla.org", "coursera.org", "udemy.com",
        "stackoverflow.com", "freecodecamp.org"
    ]

    private let utilityDomains = [
        "calendar.google.com", "keep.google.com", "todoist.com", "icloud.com"
    ]

    private let workApps = [
        "xcode", "visual studio code", "cursor", "terminal", "warp",
        "iterm", "figma", "docker", "postman", "tableplus", "simulator"
    ]

    private let entertainmentApps = [
        "music", "spotify", "tv", "steam", "vlc", "iina"
    ]

    private let communicationApps = [
        "slack", "discord", "zoom", "teams", "mail", "messages", "telegram"
    ]

    private let learningApps = [
        "books", "kindle", "obsidian"
    ]

    private let utilityApps = [
        "finder", "preview", "system settings", "calendar", "notes"
    ]

    func classify(applicationName: String, bundleIdentifier: String?, webURL: String?) -> ActivityCategory {
        if let domain = domain(from: webURL) {
            if matches(domain, candidates: workDomains) { return .work }
            if matches(domain, candidates: entertainmentDomains) { return .entertainment }
            if matches(domain, candidates: communicationDomains) { return .communication }
            if matches(domain, candidates: learningDomains) { return .learning }
            if matches(domain, candidates: utilityDomains) { return .utilities }
        }

        let appFingerprint = [applicationName, bundleIdentifier ?? ""]
            .joined(separator: " ")
            .lowercased()

        if containsAny(in: appFingerprint, patterns: workApps) { return .work }
        if containsAny(in: appFingerprint, patterns: entertainmentApps) { return .entertainment }
        if containsAny(in: appFingerprint, patterns: communicationApps) { return .communication }
        if containsAny(in: appFingerprint, patterns: learningApps) { return .learning }
        if containsAny(in: appFingerprint, patterns: utilityApps) { return .utilities }

        return .uncategorized
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

    var previewRules: [RulePreview] {
        [
            RulePreview(
                id: "work",
                category: .work,
                examples: ["GitHub", "Notion", "Figma", "Xcode", "Cursor"]
            ),
            RulePreview(
                id: "entertainment",
                category: .entertainment,
                examples: ["YouTube", "Netflix", "Spotify", "Twitch"]
            ),
            RulePreview(
                id: "communication",
                category: .communication,
                examples: ["Slack", "Discord", "Teams", "Zoom", "Mail"]
            ),
            RulePreview(
                id: "learning",
                category: .learning,
                examples: ["Apple Docs", "MDN", "Coursera", "Stack Overflow"]
            ),
            RulePreview(
                id: "utilities",
                category: .utilities,
                examples: ["Finder", "Preview", "Calendar", "Todoist"]
            ),
        ]
    }

    private func matches(_ domain: String, candidates: [String]) -> Bool {
        candidates.contains { candidate in
            domain == candidate || domain.hasSuffix(".\(candidate)")
        }
    }

    private func containsAny(in content: String, patterns: [String]) -> Bool {
        patterns.contains { content.contains($0) }
    }
}
