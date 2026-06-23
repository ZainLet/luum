import Foundation
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseCrashlytics

// Wrapper de privacidade em torno do Firebase Crashlytics.
// Nunca registra atividade do usuário, URLs ou títulos de janela.
// Só envia: versão do app, versão do macOS e UID anônimo do Firebase.
@MainActor
final class CrashReportingService {
    static let shared = CrashReportingService()

    private(set) var isActive = false

    private init() {}

    func configure(enabled: Bool, uid: String?) {
        guard enabled else {
            isActive = false
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
            return
        }

        // Requer GoogleService-Info.plist no bundle (não incluído no repo).
        // Baixar do Firebase Console e colocar em src/LUUM.Mac/GoogleService-Info.plist.
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        isActive = true

        applyMetadata(uid: uid)
    }

    func updateUserID(_ uid: String?) {
        guard isActive else { return }
        Crashlytics.crashlytics().setUserID(uid ?? "")
    }

    func recordError(_ error: Error, context: String) {
        guard isActive else { return }
        Crashlytics.crashlytics().record(error: error, userInfo: ["context": context])
    }

    private func applyMetadata(uid: String?) {
        Crashlytics.crashlytics().setUserID(uid ?? "")
        Crashlytics.crashlytics().setCustomValue(
            ProcessInfo.processInfo.operatingSystemVersionString,
            forKey: "macOS"
        )
        Crashlytics.crashlytics().setCustomValue(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev",
            forKey: "appVersion"
        )
        Crashlytics.crashlytics().setCustomValue(
            Bundle.main.object(forInfoDictionaryKey: "LuumReleaseChannel") as? String ?? "development",
            forKey: "releaseChannel"
        )
    }
}
