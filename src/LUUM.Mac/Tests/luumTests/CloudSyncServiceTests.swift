import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func cloudBackupRemovesZapierWebhookURL() {
    var preferences = MonitoringPreferencesSnapshot.default
    preferences.zapierSettings.webhookURL = "https://hooks.zapier.com/hooks/catch/secret"

    let sanitized = CloudSyncService.cloudSafePreferences(preferences)

    #expect(sanitized.zapierSettings.webhookURL.isEmpty)
}

@Test
func cloudBackupKeepsCalendarStructureWithoutCachedEventsOrTokens() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let connection = GoogleCalendarConnectionSnapshot(
        id: "user-at-luum-app",
        profile: GoogleCalendarProfile(email: "user@luum.app", name: "User", pictureURL: nil),
        calendars: [GoogleCalendarDescriptor(id: "primary", title: "Principal", isPrimary: true)],
        agendaDay: now,
        agendaItems: [
            CalendarAgendaItem(
                id: "private-event",
                accountID: "user-at-luum-app",
                accountEmail: "user@luum.app",
                accountLabel: "User",
                calendarID: "primary",
                calendarTitle: "Principal",
                calendarColorHex: nil,
                title: "Reuniao confidencial",
                location: "Sala secreta",
                notes: "Nao enviar ao Firestore",
                startDate: now,
                endDate: now.addingTimeInterval(1800),
                isAllDay: false,
                htmlLink: nil
            ),
        ],
        lastSyncAt: now,
        legacyTokens: GoogleCalendarTokens(
            accessToken: "access",
            refreshToken: "refresh",
            idToken: "id",
            tokenType: "Bearer",
            scope: "calendar",
            expiresAt: now.addingTimeInterval(3600)
        )
    )

    let sanitized = CloudSyncService.cloudSafeGoogleCalendarSnapshot(
        clientID: "public-client-id",
        connections: [connection]
    )

    #expect(sanitized.clientID == "public-client-id")
    #expect(sanitized.clientSecret.isEmpty)
    #expect(sanitized.connections.first?.calendars.first?.id == "primary")
    #expect(sanitized.connections.first?.agendaDay == nil)
    #expect(sanitized.connections.first?.agendaItems.isEmpty == true)
    #expect(sanitized.connections.first?.legacyTokens == nil)
}

@Test
func plansExposeOnlyTheirAllowedIntegrationTiers() {
    #expect(!LuumAccountPlan.essencial.includes(.agendaIntegrations))
    #expect(LuumAccountPlan.profissional.includes(.agendaIntegrations))
    #expect(!LuumAccountPlan.profissional.includes(.advancedIntegrations))
    #expect(LuumAccountPlan.equipes.includes(.advancedIntegrations))
    #expect(LuumAccountPlan.equipes.includes(.teamWorkspace))
    #expect(!LuumAccountPlan.equipes.includes(.rawActivityBackup))
    #expect(LuumAccountPlan.negocios.includes(.rawActivityBackup))
}

@Test
func lockedAuthSessionDoesNotEnableCloudOrRawBackup() {
    var settings = CloudSyncSettings.default
    settings.isEnabled = true
    settings.syncRawActivities = true

    let sanitized = ActivityStore.cloudSyncSettings(
        settings,
        sanitizedFor: makeAuthSession(plan: .trial, lastVerifiedAt: nil)
    )

    #expect(!sanitized.isEnabled)
    #expect(!sanitized.syncRawActivities)
    #expect(sanitized.endpointURL == FirebaseAuthService.defaultBaseURL)
    #expect(sanitized.backupID == "firebase-user")
}

@Test
func businessPlanKeepsRawBackupPinnedToFirebaseAccount() {
    var settings = CloudSyncSettings.default
    settings.endpointURL = "https://evil.example"
    settings.backupID = "someone-else"
    settings.syncRawActivities = true

    let sanitized = ActivityStore.cloudSyncSettings(
        settings,
        sanitizedFor: makeAuthSession(plan: .negocios, lastVerifiedAt: Date())
    )

    #expect(sanitized.isEnabled)
    #expect(sanitized.syncRawActivities)
    #expect(sanitized.endpointURL == FirebaseAuthService.defaultBaseURL)
    #expect(sanitized.backupID == "firebase-user")
}

private func makeAuthSession(plan: LuumAccountPlan, lastVerifiedAt: Date?) -> LuumAuthSession {
    LuumAuthSession(
        uid: "firebase-user",
        email: "user@luum.app",
        displayName: "User",
        idToken: "token",
        refreshToken: "refresh",
        plan: plan,
        subscriptionStatus: "active",
        lockedReason: nil,
        expiresAt: Date().addingTimeInterval(3600),
        trialEndsAt: nil,
        lastVerifiedAt: lastVerifiedAt
    )
}
#endif
