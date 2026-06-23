import Sparkle
import SwiftUI

struct CheckForUpdatesView: View {
    let updater: SPUUpdater?

    @State private var canCheckForUpdates = false

    var body: some View {
        Button("Verificar atualizações") {
            updater?.checkForUpdates()
        }
        .disabled(!canCheckForUpdates)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            canCheckForUpdates = updater?.canCheckForUpdates ?? false
        }
        .task {
            canCheckForUpdates = updater?.canCheckForUpdates ?? false
        }
    }
}
