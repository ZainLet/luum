import AppKit
import Foundation

struct BrowserContext {
    let browserName: String
    let pageTitle: String?
    let urlString: String
}

enum BrowserAutomationIssue: LocalizedError {
    case permissionDenied(String)
    case scriptFailed(String, String)

    var errorDescription: String? {
        switch self {
        case let .permissionDenied(browser):
            "Permita Automação para o luum controlar \(browser) e ler a URL da aba ativa."
        case let .scriptFailed(browser, message):
            "Não foi possível ler a aba ativa de \(browser): \(message)"
        }
    }
}

final class BrowserURLProvider {
    private static let separator = "\u{1F}"

    private let browsers: [BrowserDescriptor] = [
        .safari,
        .chrome("Google Chrome", bundleIdentifiers: ["com.google.Chrome"]),
        .chrome("Arc", bundleIdentifiers: ["company.thebrowser.Browser"]),
        .chrome("Brave Browser", bundleIdentifiers: ["com.brave.Browser"]),
        .chrome("Microsoft Edge", bundleIdentifiers: ["com.microsoft.edgemac"]),
        .chrome("Chromium", bundleIdentifiers: ["org.chromium.Chromium"]),
        .chrome("Vivaldi", bundleIdentifiers: ["com.vivaldi.Vivaldi"]),
        .chrome("Opera", bundleIdentifiers: ["com.operasoftware.Opera"]),
    ]

    func currentContext(for applicationName: String, bundleIdentifier: String?) throws -> BrowserContext? {
        guard let browser = browsers.first(where: { $0.matches(applicationName: applicationName, bundleIdentifier: bundleIdentifier) }) else {
            return nil
        }

        guard let script = NSAppleScript(source: browser.script) else {
            throw BrowserAutomationIssue.scriptFailed(browser.name, "Script invalido.")
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo, let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int {
            if errorNumber == -1743 || errorNumber == -1744 {
                throw BrowserAutomationIssue.permissionDenied(browser.name)
            }

            let message = (errorInfo[NSAppleScript.errorBriefMessage] as? String)
                ?? (errorInfo[NSAppleScript.errorMessage] as? String)
                ?? "Falha desconhecida."

            throw BrowserAutomationIssue.scriptFailed(browser.name, message)
        }

        guard let payload = descriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !payload.isEmpty else {
            return nil
        }

        let parts = payload.components(separatedBy: Self.separator)
        let title = parts.indices.contains(0) ? parts[0].nilIfBlank : nil
        let url = parts.indices.contains(1) ? parts[1].nilIfBlank : nil

        guard let url else {
            return nil
        }

        guard Self.isMeaningfulBrowserURL(url) else {
            return nil
        }

        return BrowserContext(
            browserName: browser.name,
            pageTitle: title,
            urlString: url
        )
    }

    private static func isMeaningfulBrowserURL(_ urlString: String) -> Bool {
        guard let components = URLComponents(string: urlString) else { return false }

        if let scheme = components.scheme?.lowercased(),
           ["about", "chrome", "edge", "arc", "brave", "vivaldi", "opera", "file"].contains(scheme) {
            return scheme == "file"
        }

        if let host = components.host?.lowercased(),
           !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        return false
    }
}

private struct BrowserDescriptor {
    let name: String
    let bundleIdentifiers: [String]
    let script: String

    static let safari = BrowserDescriptor(
        name: "Safari",
        bundleIdentifiers: ["com.apple.Safari"],
        script: """
        tell application id "com.apple.Safari"
            if not running then return ""
            if (count of windows) is 0 then return ""
            set pageTitle to ""
            set pageURL to ""
            try
                set pageTitle to name of current tab of front window
            end try
            try
                set pageURL to URL of current tab of front window
            end try
            return pageTitle & (ASCII character 31) & pageURL
        end tell
        """
    )

    static func chrome(_ name: String, bundleIdentifiers: [String]) -> BrowserDescriptor {
        let targetIdentifier = bundleIdentifiers.first ?? name
        return BrowserDescriptor(
            name: name,
            bundleIdentifiers: bundleIdentifiers,
            script: """
            tell application id "\(targetIdentifier)"
                if not running then return ""
                if (count of windows) is 0 then return ""
                set pageTitle to ""
                set pageURL to ""
                try
                    set pageTitle to title of active tab of front window
                end try
                try
                    set pageURL to URL of active tab of front window
                end try
                return pageTitle & (ASCII character 31) & pageURL
            end tell
            """
        )
    }

    func matches(applicationName: String, bundleIdentifier: String?) -> Bool {
        applicationName.caseInsensitiveCompare(name) == .orderedSame ||
        bundleIdentifiers.contains(bundleIdentifier ?? "")
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
