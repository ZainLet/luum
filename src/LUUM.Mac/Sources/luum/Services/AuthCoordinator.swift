import Foundation
import Observation

@MainActor
@Observable
final class AuthCoordinator {
    unowned let store: ActivityStore

    @ObservationIgnored private let authService: FirebaseAuthService
    @ObservationIgnored private let keychainService: KeychainService

    @ObservationIgnored private var authRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var authRefreshGeneration = 0
    @ObservationIgnored private var lastAuthCallbackSignature: String?
    @ObservationIgnored private var lastCompletedAuthState: String?
    var pendingAuthRequest: LuumAuthRequest?

    @ObservationIgnored static let firebaseAuthSessionKey = "firebase-auth-session"
    @ObservationIgnored static let firebaseAuthRequestKey = "firebase-auth-request"

    init(store: ActivityStore, authService: FirebaseAuthService, keychainService: KeychainService) {
        self.store = store
        self.authService = authService
        self.keychainService = keychainService
    }

    // MARK: - Public API

    func handleAuthCallbackURL(_ url: URL) {
        let callbackState = FirebaseAuthService.callbackState(from: url)
        guard let pendingAuthRequest, pendingAuthRequest.isValid() else {
            if Self.isDuplicateCompletedAuthCallback(callbackState: callbackState, completedState: lastCompletedAuthState) {
                return
            }
            clearPendingAuthRequest()
            store.authStatusMessage = "Esta solicitação de login expirou. Clique em Entrar e tente novamente."
            return
        }

        do {
            let session = try authService.session(from: url, expectedState: pendingAuthRequest.state)
            let callbackSignature = Self.authCallbackSignature(for: session)
            if callbackSignature == lastAuthCallbackSignature,
               store.isCheckingAuth || store.authSession?.idToken == session.idToken {
                store.authStatusMessage = "Login recebido. Validação já está em andamento..."
                return
            }

            lastAuthCallbackSignature = callbackSignature
            lastCompletedAuthState = pendingAuthRequest.state
            clearPendingAuthRequest()
            applyAuthSession(session, message: "Login recebido. Validando plano no Firebase...")
            refreshAccountStatus(restartInFlight: true)
        } catch {
            store.authStatusMessage = error.localizedDescription
        }
    }

    func refreshAccountStatus() {
        refreshAccountStatus(restartInFlight: false)
    }

    func signOut() {
        authRefreshTask?.cancel()
        authRefreshTask = nil
        authRefreshGeneration += 1
        lastAuthCallbackSignature = nil
        lastCompletedAuthState = nil
        clearPendingAuthRequest()
        store.isCheckingAuth = false
        store.authSession = nil
        store.authStatusMessage = "Conta desconectada deste Mac."
        keychainService.removeValue(for: Self.firebaseAuthSessionKey)
    }

    func verifiedAuthSessionForProtectedRequest() async throws -> LuumAuthSession {
        guard let sessionToValidate = store.authSession else {
            throw FirebaseAuthServiceError.statusRejected("missing_session")
        }

        do {
            let verified = try await authService.verifiedSession(
                sessionToValidate,
                deviceID: keychainService.installationID()
            )
            guard isCurrentAuthSession(sessionToValidate) else { throw CancellationError() }
            persistAuthSession(verified, message: "Plano \(verified.plan.title) validado.", scheduleCloudSync: false)
            return verified
        } catch {
            if Self.isExplicitAuthRejection(error) {
                rejectAuthSession(sessionToValidate)
            }
            throw error
        }
    }

    func isCurrentVerifiedSession(_ verified: LuumAuthSession) -> Bool {
        guard let current = store.authSession else { return false }
        return current.uid == verified.uid && current.idToken == verified.idToken
    }

    nonisolated static func authCallbackSignature(for session: LuumAuthSession) -> String {
        "\(session.uid):\(session.idToken.suffix(16))"
    }

    nonisolated static func isDuplicateCompletedAuthCallback(callbackState: String?, completedState: String?) -> Bool {
        guard let callbackState, !callbackState.isEmpty else { return false }
        return callbackState == completedState
    }

    func clearPendingAuthRequest() {
        pendingAuthRequest = nil
        keychainService.removeValue(for: Self.firebaseAuthRequestKey)
    }

    // MARK: - Private

    private func refreshAccountStatus(restartInFlight: Bool) {
        guard let authSession = store.authSession else {
            store.authStatusMessage = "Entre com sua conta Luum para validar o plano."
            return
        }

        if store.isCheckingAuth {
            guard restartInFlight else { return }
            authRefreshTask?.cancel()
        }

        authRefreshGeneration += 1
        let generation = authRefreshGeneration
        let sessionToValidate = authSession
        store.isCheckingAuth = true
        let weakStore = store
        authRefreshTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            do {
                let verified = try await authService.verifiedSession(
                    sessionToValidate,
                    deviceID: keychainService.installationID()
                )
                let (shouldSyncWorkspace, idToken) = await MainActor.run {
                    guard self.isCurrentAuthRefresh(generation, for: sessionToValidate) else { return (false, "") }
                    self.applyAuthSession(verified, message: "Plano \(verified.plan.title) validado.")
                    self.store.isCheckingAuth = false
                    self.authRefreshTask = nil
                    let sync = weakStore.teamSettings.automaticallySyncWorkspace &&
                        weakStore.teamWorkspaceConfigured
                    return (sync, verified.idToken)
                }
                if !idToken.isEmpty {
                    await CrashReportService.sendPending(idToken: idToken)
                }
                if shouldSyncWorkspace {
                    weakStore.syncWorkspaceRankingNow()
                }
            } catch {
                let wasCancelled = Task.isCancelled
                await MainActor.run {
                    guard self.isCurrentAuthRefresh(generation, for: sessionToValidate) else { return }
                    if wasCancelled {
                        self.store.isCheckingAuth = false
                        self.authRefreshTask = nil
                        return
                    }

                    if error is URLError {
                        let offline = sessionToValidate
                        let message = offline.isLocked
                            ? "Conecte-se a internet e valide seu plano para liberar o app."
                            : "Sem conexão com a API. Usando sessão local validada por até 24 horas."
                        self.applyAuthSession(offline, message: message)
                    } else if Self.isExplicitAuthRejection(error) {
                        self.rejectAuthSession(sessionToValidate)
                    } else {
                        let offline = sessionToValidate
                        let message = offline.isLocked
                            ? "Não foi possível validar o plano agora. Tente novamente em instantes."
                            : "A API de assinatura respondeu de forma temporária. Usando sessão local validada por até 24 horas."
                        self.applyAuthSession(offline, message: message)
                    }
                    self.store.isCheckingAuth = false
                    self.authRefreshTask = nil
                }
            }
        }
    }

    private func applyAuthSession(_ session: LuumAuthSession, message: String) {
        persistAuthSession(session, message: message, scheduleCloudSync: true)
    }

    private func persistAuthSession(_ session: LuumAuthSession, message: String, scheduleCloudSync: Bool) {
        store.authSession = session
        store.authStatusMessage = message
        do {
            try keychainService.setCodable(session, for: Self.firebaseAuthSessionKey)
        } catch {
            store.authStatusMessage = error.localizedDescription
        }

        var cloudSyncSettings = store.monitoringPreferences.cloudSyncSettings
        var teamSettings = store.monitoringPreferences.teamSettings
        teamSettings.workspaceEndpointURL = FirebaseAuthService.defaultBaseURL
        cloudSyncSettings = ActivityStore.cloudSyncSettings(
            cloudSyncSettings,
            sanitizedFor: session
        )
        store.monitoringPreferences.cloudSyncSettings = cloudSyncSettings
        store.monitoringPreferences.teamSettings = teamSettings

        store.persistMonitoringPreferences()
        if scheduleCloudSync {
            store.scheduleCloudSyncIfNeeded(reason: "auth-session")
        }

        if store.canUse(.coreTracking) {
            store.startMonitoring()
        } else {
            store.stopMonitoring()
        }
    }

    private func isCurrentAuthRefresh(_ generation: Int, for session: LuumAuthSession) -> Bool {
        guard generation == authRefreshGeneration else { return false }
        return isCurrentAuthSession(session)
    }

    private func isCurrentAuthSession(_ session: LuumAuthSession) -> Bool {
        guard let current = store.authSession else { return false }
        return current.uid == session.uid && current.idToken == session.idToken
    }

    private func rejectAuthSession(_ session: LuumAuthSession) {
        var rejected = session
        rejected.lockedReason = "auth_validation_failed"
        rejected.lastVerifiedAt = nil
        persistAuthSession(
            rejected,
            message: "A sessão não foi aceita pela API. Entre novamente para liberar o app.",
            scheduleCloudSync: false
        )
    }

    private static func isExplicitAuthRejection(_ error: Error) -> Bool {
        (error as? FirebaseAuthServiceError)?.isExplicitAuthRejection ?? false
    }
}
