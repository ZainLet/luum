import Foundation

struct ClassificationEngine {
    private static let supportedBrowserNames: Set<String> = [
        "safari",
        "google chrome",
        "arc",
        "brave browser",
        "microsoft edge",
        "chromium",
        "vivaldi",
        "opera",
    ]

    private static let supportedBrowserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "org.chromium.Chromium",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
    ]
    .map { $0.lowercased() }
    .reduce(into: Set<String>()) { partialResult, item in
        partialResult.insert(item)
    }

    static let defaultRules: [CategoryRule] =
        rules(
            categoryID: ActivityCategory.work.id,
            matchTarget: .domain,
            patterns: [
                "github.com",
                "gitlab.com",
                "bitbucket.org",
                "linear.app",
                "clickup.com",
                "asana.com",
                "trello.com",
                "monday.com",
                "notion.so",
                "notion.site",
                "figma.com",
                "miro.com",
                "canva.com",
                "vercel.com",
                "atlassian.net",
                "docs.google.com",
                "drive.google.com",
                "sheets.google.com",
                "slides.google.com",
                "airtable.com",
                "openai.com",
                "chatgpt.com",
            ]
        )
        + rules(
            categoryID: ActivityCategory.entertainment.id,
            matchTarget: .domain,
            patterns: [
                "youtube.com",
                "netflix.com",
                "twitch.tv",
                "spotify.com",
                "disneyplus.com",
                "primevideo.com",
                "max.com",
                "crunchyroll.com",
                "reddit.com",
                "instagram.com",
                "tiktok.com",
                "x.com",
                "twitter.com",
            ]
        )
        + rules(
            categoryID: ActivityCategory.communication.id,
            matchTarget: .domain,
            patterns: [
                "slack.com",
                "discord.com",
                "teams.microsoft.com",
                "meet.google.com",
                "zoom.us",
                "web.whatsapp.com",
                "mail.google.com",
                "outlook.live.com",
                "telegram.org",
            ]
        )
        + rules(
            categoryID: ActivityCategory.learning.id,
            matchTarget: .domain,
            patterns: [
                "developer.apple.com",
                "docs.swift.org",
                "learn.microsoft.com",
                "developer.mozilla.org",
                "coursera.org",
                "udemy.com",
                "stackoverflow.com",
                "freecodecamp.org",
                "medium.com",
                "substack.com",
            ]
        )
        + rules(
            categoryID: ActivityCategory.utilities.id,
            matchTarget: .domain,
            patterns: [
                "calendar.google.com",
                "keep.google.com",
                "todoist.com",
                "icloud.com",
            ]
        )
        + rules(
            categoryID: ActivityCategory.work.id,
            matchTarget: .applicationName,
            patterns: [
                "xcode",
                "visual studio code",
                "vs code",
                "cursor",
                "codex",
                "windsurf",
                "intellij idea",
                "android studio",
                "pycharm",
                "webstorm",
                "sublime text",
                "nova",
                "terminal",
                "warp",
                "iterm",
                "opencode",
                "figma",
                "sketch",
                "docker",
                "postman",
                "tableplus",
                "sequel ace",
                "datagrip",
                "filezilla",
                "simulator",
                "notion",
                "clickup",
                "linear",
                "google docs",
                "google sheets",
                "google slides",
                "windows app",
                "adobe premiere pro",
                "adobe premiere",
                "adobe photoshop",
                "adobe illustrator",
                "adobe after effects",
                "adobe media encoder",
                "adobe lightroom",
                "final cut pro",
                "davinci resolve",
                "blender",
                "canva",
                "obs",
                "mister horse product manager",
                "dagger",
                "spell book",
                "blinkl.io",
            ]
        )
        + rules(
            categoryID: ActivityCategory.work.id,
            matchTarget: .bundleIdentifier,
            patterns: [
                "com.microsoft.vscode",
                "com.todesktop.230313mzl4w4u92",
                "com.openai.codex",
                "ai.opencode.desktop",
                "com.figma.desktop",
                "org.filezilla-project.filezilla",
                "com.google.drivefs.shortcuts.docs",
                "com.google.drivefs.shortcuts.sheets",
                "com.google.drivefs.shortcuts.slides",
                "com.microsoft.rdc.macos",
                "com.adobe.premierepro",
                "com.adobe.photoshop",
                "com.adobe.aftereffects",
                "com.adobe.ame.application",
                "org.blenderfoundation.blender",
                "com.obsproject.obs-studio",
                "com.misterhorse.productmanager",
                "knights.of.the.editing.table.dagger",
                "knights.of.the.editing.table.spellbook",
                "io.blinkl.ea",
            ]
        )
        + rules(
            categoryID: ActivityCategory.entertainment.id,
            matchTarget: .applicationName,
            patterns: [
                "music",
                "spotify",
                "tv",
                "steam",
                "epic games",
                "battle.net",
                "vlc",
                "iina",
                "plex",
                "netflix",
                "qbittorrent",
            ]
        )
        + rules(
            categoryID: ActivityCategory.entertainment.id,
            matchTarget: .bundleIdentifier,
            patterns: [
                "com.spotify.client",
                "com.valvesoftware.steam",
                "org.qbittorrent.qbittorrent",
                "com.apple.music",
                "com.apple.tv",
                "com.apple.podcasts",
                "com.apple.chess",
                "com.apple.games",
            ]
        )
        + rules(
            categoryID: ActivityCategory.communication.id,
            matchTarget: .applicationName,
            patterns: [
                "slack",
                "discord",
                "zoom",
                "microsoft teams",
                "gather",
                "mail",
                "messages",
                "telegram",
                "whatsapp",
                "facetime",
                "spark",
            ]
        )
        + rules(
            categoryID: ActivityCategory.communication.id,
            matchTarget: .bundleIdentifier,
            patterns: [
                "com.tinyspeck.slackmacgap",
                "com.hnc.discord",
                "com.gather.gather",
                "com.gather.gatherv2",
                "net.whatsapp.whatsapp",
                "com.apple.mail",
                "com.apple.mobilesms",
                "com.apple.facetime",
            ]
        )
        + rules(
            categoryID: ActivityCategory.learning.id,
            matchTarget: .applicationName,
            patterns: [
                "books",
                "kindle",
                "obsidian",
                "bear",
                "notability",
                "goodnotes",
            ]
        )
        + rules(
            categoryID: ActivityCategory.learning.id,
            matchTarget: .bundleIdentifier,
            patterns: [
                "md.obsidian",
                "com.apple.ibooksx",
                "com.apple.dictionary",
            ]
        )
        + rules(
            categoryID: ActivityCategory.utilities.id,
            matchTarget: .applicationName,
            patterns: [
                "preview",
                "calendar",
                "notes",
                "reminders",
                "todoist",
                "things",
                "numbers",
                "pages",
                "keynote",
                "microsoft excel",
                "microsoft word",
                "microsoft powerpoint",
                "raycast",
                "1password",
                "bitwarden",
                "google drive",
                "rize",
                "tailscale",
                "rar extractor",
                "unarchiver",
                "appcleaner",
            ]
        )
        + rules(
            categoryID: ActivityCategory.utilities.id,
            matchTarget: .bundleIdentifier,
            patterns: [
                "com.bitwarden.desktop",
                "com.google.drivefs",
                "io.rize",
                "io.tailscale.ipn.macsys",
                "net.freemacsoft.appcleaner",
                "com.ababe.rarextractorfree",
                "com.apple.preview",
                "com.apple.ical",
                "com.apple.notes",
                "com.apple.reminders",
                "com.apple.calculator",
                "com.apple.passwords",
            ]
        )

    private static let defaultIgnoredApplicationPatterns: Set<String> = [
        "com.apple.controlcenter",
        "control center",
        "com.apple.notificationcenterui",
        "notification center",
        "com.apple.dock",
        "com.apple.finder",
        "finder",
        "com.apple.systemuiserver",
        "systemuiserver",
        "com.apple.systempreferences",
        "com.apple.systemsettings",
        "system settings",
        "com.apple.activitymonitor",
        "activity monitor",
        "com.apple.console",
        "console",
        "com.apple.diskutility",
        "disk utility",
        "com.apple.systemprofiler",
        "system information",
        "com.apple.screenshot.launcher",
        "screenshot",
        "com.apple.printcenter",
        "print center",
        "com.apple.migrateassistant",
        "migration assistant",
        "com.apple.bootcampassistant",
        "boot camp assistant",
        "com.apple.audio.audiomidisetup",
        "audio midi setup",
        "com.apple.bluetoothfileexchange",
        "bluetooth file exchange",
        "com.apple.colorsyncutility",
        "colorsync utility",
        "com.apple.digitalcolormeter",
        "digital color meter",
        "com.apple.airport.airportutility",
        "airport utility",
        "com.apple.voiceoverutility",
        "voiceover utility",
        "windowserver",
        "loginwindow",
        "spotlight",
        "siri",
        "textinputmenuagent",
        "coreservicesuiagent",
        "usernotificationcenter",
        "keyboardsetupassistant",
        "screensaverengine",
        "wallpaper",
    ]

    private static func rules(
        categoryID: String,
        matchTarget: RuleMatchTarget,
        patterns: [String]
    ) -> [CategoryRule] {
        patterns.map {
            CategoryRule(categoryID: categoryID, matchTarget: matchTarget, pattern: $0)
        }
    }

    func classify(
        applicationName: String,
        bundleIdentifier: String?,
        webURL: String?,
        preferences: MonitoringPreferencesSnapshot = .default
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
        if let manualCategoryID = sample.manualCategoryID,
           let manualCategory = preferences.category(for: manualCategoryID) {
            return manualCategory
        }

        return classify(
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
        if isDomainIgnored(webURL: webURL, preferences: preferences) {
            return true
        }

        if isApplicationIgnored(
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier,
            preferences: preferences
        ) {
            let hasBrowserContext = isSupportedBrowser(
                applicationName: applicationName,
                bundleIdentifier: bundleIdentifier
            ) && domain(from: webURL) != nil

            return !hasBrowserContext
        }

        return false
    }

    func isApplicationIgnored(
        applicationName: String,
        bundleIdentifier: String?,
        preferences: MonitoringPreferencesSnapshot
    ) -> Bool {
        let appFingerprint = [applicationName, bundleIdentifier ?? ""]
            .joined(separator: " ")
            .lowercased()

        if Self.defaultIgnoredApplicationPatterns.contains(where: { appFingerprint.contains($0) }) {
            return true
        }

        return preferences.ignoredApplications.contains(where: { normalizedPattern in
            appFingerprint.contains(normalizedPattern)
        })
    }

    func isDomainIgnored(
        webURL: String?,
        preferences: MonitoringPreferencesSnapshot
    ) -> Bool {
        guard let domain = domain(from: webURL) else {
            return false
        }

        return preferences.ignoredDomains.contains(where: { normalizedPattern in
            domain == normalizedPattern || domain.hasSuffix(".\(normalizedPattern)")
        })
    }

    func isSupportedBrowser(
        applicationName: String,
        bundleIdentifier: String?
    ) -> Bool {
        let normalizedName = normalized(applicationName)
        let normalizedBundleID = normalized(bundleIdentifier ?? "")

        if Self.supportedBrowserNames.contains(normalizedName) {
            return true
        }

        return Self.supportedBrowserBundleIDs.contains(normalizedBundleID)
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

    func searchQuery(from webURL: String?) -> String? {
        guard
            let webURL,
            let components = URLComponents(string: webURL)
        else {
            return nil
        }

        let host = (components.host ?? "").lowercased()
        let queryItems = components.queryItems ?? []

        let candidateKeys: [String]
        switch host {
        case let host where host.contains("google."):
            candidateKeys = ["q"]
        case let host where host.contains("bing.com"):
            candidateKeys = ["q"]
        case let host where host.contains("duckduckgo.com"):
            candidateKeys = ["q"]
        case let host where host.contains("youtube.com"):
            candidateKeys = ["search_query"]
        case let host where host.contains("x.com"), let host where host.contains("twitter.com"):
            candidateKeys = ["q"]
        case let host where host.contains("github.com"):
            candidateKeys = ["q"]
        default:
            candidateKeys = ["q", "query", "search", "text", "wd", "p"]
        }

        for key in candidateKeys {
            if let rawValue = queryItems.first(where: { $0.name.caseInsensitiveCompare(key) == .orderedSame })?.value {
                let cleaned = rawValue
                    .replacingOccurrences(of: "+", with: " ")
                    .removingPercentEncoding?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let cleaned, !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return nil
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
