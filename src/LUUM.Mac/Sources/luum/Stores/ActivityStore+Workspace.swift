import Foundation

extension ActivityStore {
    // MARK: - Workspace / Team

    func updateTeamOrganizationName(_ value: String) {
        monitoringPreferences.teamSettings.organizationName = value
        persistMonitoringPreferences()
    }

    func updateTeamMemberDisplayName(_ value: String) {
        monitoringPreferences.teamSettings.memberDisplayName = value
        persistMonitoringPreferences()
    }

    func updateTeamRoleLabel(_ value: String) {
        monitoringPreferences.teamSettings.roleLabel = value
        persistMonitoringPreferences()
    }

    func updateTeamSharesAnonymousMetrics(_ value: Bool) {
        if value && !canUse(.teamWorkspace) {
            monitoringPreferences.teamSettings.sharesAnonymousMetrics = false
            workspaceSyncStatusMessage = lockMessage(for: .teamWorkspace)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.teamSettings.sharesAnonymousMetrics = value
        persistMonitoringPreferences()
    }

    func updateTeamWorkspaceID(_ value: String) {
        monitoringPreferences.teamSettings.workspaceID = value
        persistMonitoringPreferences()
    }

    func updateTeamWorkspaceMemberID(_ value: String) {
        monitoringPreferences.teamSettings.workspaceMemberID = value
        persistMonitoringPreferences()
    }

    func updateTeamWorkspaceEndpointURL(_ value: String) {
        monitoringPreferences.teamSettings.workspaceEndpointURL = FirebaseAuthService.defaultBaseURL
        persistMonitoringPreferences()
    }

    func updateTeamAutomaticallySyncWorkspace(_ value: Bool) {
        if value && !canUse(.teamWorkspace) {
            monitoringPreferences.teamSettings.automaticallySyncWorkspace = false
            workspaceSyncStatusMessage = lockMessage(for: .teamWorkspace)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.teamSettings.automaticallySyncWorkspace = value
        persistMonitoringPreferences()
    }

    func updateTeamWorkspaceSecret(_ value: String) {
        do {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keychainService.removeValue(for: Self.teamWorkspaceSecretKey)
                workspaceSyncStatusMessage = "Chave do workspace removida deste Mac."
            } else {
                try keychainService.setString(value, for: Self.teamWorkspaceSecretKey)
                workspaceSyncStatusMessage = "Chave do workspace atualizada neste Mac."
            }
        } catch {
            workspaceSyncStatusMessage = error.localizedDescription
        }
    }

    func syncWorkspaceRankingNow(for day: Date = Date()) {
        guard !isSyncingWorkspace else { return }
        workspaceSyncTask?.cancel()
        workspaceSyncTask = Task { [weak self] in
            await self?.runWorkspaceSync(for: day, force: true)
        }
    }

    func fetchWorkspaceAdminList() {
        Task { await runFetchAdminList() }
    }

    func promoteWorkspaceMember(uid: String) {
        Task { await runAdminAction("promote", targetUID: uid) }
    }

    func demoteWorkspaceMember(uid: String) {
        Task { await runAdminAction("demote", targetUID: uid) }
    }

    func removeWorkspaceMember(uid: String) {
        Task { await runAdminAction("remove", targetUID: uid) }
    }

    func runWorkspaceSync(for day: Date, force: Bool) async {
        guard teamWorkspaceConfigured else {
            if force {
                workspaceSyncStatusMessage = "Preencha endpoint, Workspace ID e chave para liberar o ranking corporativo."
            }
            return
        }

        guard let secret = workspaceSecret,
              !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            workspaceSyncStatusMessage = WorkspaceSyncError.missingSecret.errorDescription
            return
        }

        isSyncingWorkspace = true
        defer { isSyncingWorkspace = false }

        do {
            let verified = try await verifiedAuthSessionForProtectedRequest()
            guard verified.includes(.teamWorkspace) else {
                workspaceSyncStatusMessage = lockMessage(for: .teamWorkspace)
                return
            }
            let payload = makeWorkspaceMemberPayload(for: day)
            let updatedAt = try await workspaceSyncService.push(
                baseURL: FirebaseAuthService.defaultBaseURL,
                workspaceID: teamSettings.workspaceID,
                memberID: teamSettings.workspaceMemberID,
                secret: secret,
                firebaseToken: verified.idToken,
                payload: payload
            )
            guard isCurrentVerifiedSession(verified) else { return }
            let ranking = try await workspaceSyncService.fetchRanking(
                baseURL: FirebaseAuthService.defaultBaseURL,
                workspaceID: teamSettings.workspaceID,
                memberID: teamSettings.workspaceMemberID,
                secret: secret,
                firebaseToken: verified.idToken
            )
            guard isCurrentVerifiedSession(verified) else { return }
            workspaceRankingEntries = ranking.entries
            isCurrentUserWorkspaceAdmin = ranking.isCurrentUserAdmin
            workspaceSyncLastSyncAt = ranking.updatedAt ?? updatedAt
            workspaceSyncStatusMessage = workspaceRankingEntries.isEmpty
                ? "Workspace sincronizado sem membros suficientes para ranking."
                : "Workspace sincronizado com \(workspaceRankingEntries.count) membro(s)."
            await sendZapierWorkspaceEventIfNeeded(memberCount: workspaceRankingEntries.count)
        } catch is CancellationError {
            return
        } catch {
            workspaceSyncStatusMessage = error.localizedDescription
        }
    }

    private func runFetchAdminList() async {
        guard isCurrentUserWorkspaceAdmin else { return }
        guard let secret = keychainService.string(for: Self.teamWorkspaceSecretKey),
              let verified = try? await authCoordinator.verifiedAuthSessionForProtectedRequest()
        else { return }

        isLoadingAdminList = true
        defer { isLoadingAdminList = false }
        do {
            let response = try await WorkspaceSyncService().fetchAdminList(
                baseURL: teamSettings.workspaceEndpointURL,
                workspaceID: teamSettings.workspaceID,
                secret: secret,
                firebaseToken: verified.idToken
            )
            workspaceAdminEntries = response.members
        } catch {
            workspaceSyncStatusMessage = error.localizedDescription
        }
    }

    private func runAdminAction(_ action: String, targetUID: String) async {
        guard isCurrentUserWorkspaceAdmin else { return }
        guard let secret = keychainService.string(for: Self.teamWorkspaceSecretKey),
              let verified = try? await authCoordinator.verifiedAuthSessionForProtectedRequest()
        else { return }

        do {
            try await WorkspaceSyncService().patchAdminAction(
                baseURL: teamSettings.workspaceEndpointURL,
                workspaceID: teamSettings.workspaceID,
                action: action,
                targetUID: targetUID,
                secret: secret,
                firebaseToken: verified.idToken
            )
            await runFetchAdminList()
        } catch {
            workspaceSyncStatusMessage = error.localizedDescription
        }
    }

    func makeTeamScore(
        trackedTime: TimeInterval,
        focusTime: TimeInterval,
        plannedTime: TimeInterval,
        contextSwitches: Int
    ) -> Int {
        let utilization = plannedTime > 0 ? min(trackedTime / plannedTime, 1.25) : 1
        let focusRatio = trackedTime > 0 ? min(focusTime / trackedTime, 1) : 0
        let switchPenalty = min(Double(contextSwitches) / 120, 0.2)
        let rawScore = (utilization * 52) + (focusRatio * 38) + ((1 - switchPenalty) * 10)
        return max(0, min(100, Int(rawScore.rounded())))
    }

    private func makeWorkspaceMemberPayload(for day: Date) -> WorkspaceMemberSnapshotPayload {
        let report = weeklyReport(containing: day)
        let plannedTime = max(report.totalTrackedTime * 0.92, report.averageDailyTrackedTime * 5)
        let score = makeTeamScore(
            trackedTime: report.totalTrackedTime,
            focusTime: report.focusTime,
            plannedTime: plannedTime,
            contextSwitches: report.contextSwitches
        )

        return WorkspaceMemberSnapshotPayload(
            organizationName: teamSettings.organizationName,
            memberDisplayName: teamSettings.memberDisplayName,
            roleLabel: teamSettings.roleLabel,
            trackedTime: report.totalTrackedTime,
            focusTime: report.focusTime,
            plannedTime: plannedTime,
            contextSwitches: report.contextSwitches,
            score: score,
            snapshotDay: Calendar.autoupdatingCurrent.startOfDay(for: day),
            weekStart: report.startDate,
            weekEnd: report.endDate
        )
    }
}
