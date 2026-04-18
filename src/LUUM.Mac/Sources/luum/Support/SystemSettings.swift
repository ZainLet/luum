import AppKit
import Foundation

enum SystemSettings {
    static func openAutomationPrivacy() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    static func openActivityLogFolder() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let luumDirectory = supportDirectory.appendingPathComponent("luum", isDirectory: true)

        try? FileManager.default.createDirectory(at: luumDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(luumDirectory)
    }
}
