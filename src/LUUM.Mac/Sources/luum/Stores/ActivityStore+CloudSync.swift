import Foundation

extension ActivityStore {
    // MARK: - Cloud Sync

    func updateCloudSyncEnabled(_ value: Bool) {
        if value && !canUse(.cloudBackup) {
            monitoringPreferences.cloudSyncSettings.isEnabled = false
            cloudSyncStatusMessage = lockMessage(for: .cloudBackup)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.cloudSyncSettings.isEnabled = value
        persistMonitoringPreferences()
        if value {
            scheduleCloudSyncIfNeeded(reason: "cloud-enabled")
        } else {
            cloudSyncTask?.cancel()
            cloudSyncTask = nil
            cloudSyncPendingAfterCurrent = false
        }
    }

    func updateCloudSyncEndpointURL(_ value: String) {
        monitoringPreferences.cloudSyncSettings.endpointURL = FirebaseAuthService.defaultBaseURL
        persistMonitoringPreferences()
    }

    func updateCloudSyncBackupID(_ value: String) {
        monitoringPreferences.cloudSyncSettings.backupID = authSession?.uid ?? ""
        persistMonitoringPreferences()
    }

    func updateCloudSyncSyncRawActivities(_ value: Bool) {
        if value && !canUse(.rawActivityBackup) {
            monitoringPreferences.cloudSyncSettings.syncRawActivities = false
            cloudSyncStatusMessage = lockMessage(for: .rawActivityBackup)
            persistMonitoringPreferences()
            return
        }

        monitoringPreferences.cloudSyncSettings.syncRawActivities = value
        persistMonitoringPreferences()
    }

    func updateCloudSyncSyncDailySummaries(_ value: Bool) {
        monitoringPreferences.cloudSyncSettings.syncDailySummaries = value
        persistMonitoringPreferences()
    }

    func updateCloudSyncSyncCategories(_ value: Bool) {
        monitoringPreferences.cloudSyncSettings.syncCategoriesAndRules = value
        persistMonitoringPreferences()
    }

    func syncCloudBackupNow() {
        guard !isSyncingCloud else { return }
        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            await self?.runCloudSync()
        }
    }

    func restoreCloudBackup() {
        guard !isSyncingCloud else { return }
        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            await self?.runCloudRestore()
        }
    }

    func runCloudSync() async {
        guard monitoringPreferences.cloudSyncSettings.isEnabled else { return }
        guard !isSyncingCloud else {
            cloudSyncPendingAfterCurrent = true
            return
        }

        isSyncingCloud = true
        defer {
            let shouldSchedulePendingSync = cloudSyncPendingAfterCurrent
            cloudSyncPendingAfterCurrent = false
            isSyncingCloud = false
            if shouldSchedulePendingSync {
                scheduleCloudSyncIfNeeded(reason: "pending-changes")
            }
        }

        do {
            let verified = try await verifiedAuthSessionForProtectedRequest()
            guard verified.includes(.cloudBackup) else {
                cloudSyncStatusMessage = lockMessage(for: .cloudBackup)
                return
            }
            guard cloudSyncConfigured else {
                cloudSyncStatusMessage = "Entre na conta Luum e valide o plano para ativar o backup Firebase."
                return
            }
            let updatedAt = try await cloudSyncService.push(
                baseURL: FirebaseAuthService.defaultBaseURL,
                backupID: verified.uid,
                firebaseToken: verified.idToken,
                payload: makeCloudBackupPayload()
            )
            guard isCurrentVerifiedSession(verified) else { return }
            cloudSyncLastSyncAt = updatedAt
            cloudSyncStatusMessage = "Backup sincronizado com sucesso."
        } catch is CancellationError {
            return
        } catch {
            cloudSyncStatusMessage = friendlyNetworkError(error)
        }
    }

    func runCloudRestore() async {
        isSyncingCloud = true
        defer { isSyncingCloud = false }

        do {
            let verified = try await verifiedAuthSessionForProtectedRequest()
            guard verified.includes(.cloudBackup) else {
                cloudSyncStatusMessage = lockMessage(for: .cloudBackup)
                return
            }
            guard cloudSyncConfigured else {
                cloudSyncStatusMessage = "Entre na conta Luum e valide o plano antes de restaurar."
                return
            }
            guard let payload = try await cloudSyncService.pull(
                baseURL: FirebaseAuthService.defaultBaseURL,
                backupID: verified.uid,
                firebaseToken: verified.idToken
            ) else {
                cloudSyncStatusMessage = "Nenhum backup encontrado para esse identificador."
                return
            }
            guard isCurrentVerifiedSession(verified) else { return }

            monitoringPreferences = mergeRestoredMonitoringPreferences(payload.monitoringPreferences)
            googleCalendarClientID = payload.googleCalendarSnapshot.clientID
            googleCalendarConnections = payload.googleCalendarSnapshot.connections
            if canUse(.rawActivityBackup), let rawActivities = payload.rawActivities {
                samples = rawActivities
                sortSamples()
            }

            if !googleCalendarConnections.isEmpty {
                googleCalendarStatusMessage = "Estrutura da agenda restaurada. Se este Mac ainda não tiver os tokens locais, reconecte as contas Google."
            }

            persistMonitoringPreferences()
            persistGoogleCalendar()
            schedulePersistence()
            invalidateSummaries()
            cloudSyncStatusMessage = "Backup restaurado com sucesso."
        } catch is CancellationError {
            return
        } catch {
            cloudSyncStatusMessage = friendlyNetworkError(error)
        }
    }

    private func makeCloudBackupPayload() -> CloudBackupPayload {
        let retentionDays = monitoringPreferences.privacySettings.retentionDays
        let summaries: [CloudDailySummarySnapshot]

        if monitoringPreferences.cloudSyncSettings.syncDailySummaries {
            let calendar = Calendar.autoupdatingCurrent
            summaries = (0 ..< retentionDays).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
                let summary = summary(for: day)
                guard summary.totalTrackedTime > 0 else { return nil }

                return CloudDailySummarySnapshot(
                    day: calendar.startOfDay(for: day),
                    totalTrackedTime: summary.totalTrackedTime,
                    categoryDurations: Dictionary(uniqueKeysWithValues: summary.categoryBreakdown.map { ($0.category.id, $0.duration) })
                )
            }
        } else {
            summaries = []
        }

        let rawActivities: [ActivitySample]?
        if monitoringPreferences.cloudSyncSettings.syncRawActivities && canUse(.rawActivityBackup) {
            rawActivities = samples.map(makeCloudSafeSample)
        } else {
            rawActivities = nil
        }

        return CloudBackupPayload(
            schemaVersion: 1,
            exportedAt: Date(),
            deviceName: Host.current().localizedName ?? "Mac",
            account: authSession.map {
                CloudAccountSnapshot(
                    uid: $0.uid,
                    email: $0.email,
                    displayName: $0.displayName,
                    plan: $0.plan,
                    subscriptionStatus: $0.subscriptionStatus
                )
            },
            monitoringPreferences: CloudSyncService.cloudSafePreferences(monitoringPreferences),
            googleCalendarSnapshot: CloudSyncService.cloudSafeGoogleCalendarSnapshot(
                clientID: googleCalendarClientID,
                connections: googleCalendarConnections
            ),
            dailySummaries: summaries,
            rawActivities: rawActivities
        )
    }

    private func makeCloudSafeSample(_ sample: ActivitySample) -> ActivitySample {
        guard monitoringPreferences.privacySettings.syncOnlyDomains else {
            return sample
        }

        var sanitized = sample
        sanitized.webURL = sample.webDomain.map { "https://\($0)" }
        sanitized.pageTitle = nil
        return sanitized
    }

    private func mergeRestoredMonitoringPreferences(_ restored: MonitoringPreferencesSnapshot) -> MonitoringPreferencesSnapshot {
        var merged = restored

        if !monitoringPreferences.cloudSyncSettings.syncCategoriesAndRules {
            merged.categories = monitoringPreferences.categories
            merged.categoryRules = monitoringPreferences.categoryRules
            merged.ignoredApplications = monitoringPreferences.ignoredApplications
            merged.ignoredDomains = monitoringPreferences.ignoredDomains
            merged.reminderProfiles = monitoringPreferences.reminderProfiles
        }

        merged.privacySettings = monitoringPreferences.privacySettings
        merged.cloudSyncSettings = monitoringPreferences.cloudSyncSettings
        return merged.normalized()
    }
}
