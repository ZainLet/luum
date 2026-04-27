import Foundation
import UserNotifications

@MainActor
final class ReminderEngine {
    var onPermissionMessage: ((String?, Bool) -> Void)?
    var onReminderMessage: ((String?) -> Void)?

    private let notificationCenter: UNUserNotificationCenter
    private let streakGapTolerance: TimeInterval
    private var lastDeliveredAt: [UUID: Date] = [:]

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        streakGapTolerance: TimeInterval = 90
    ) {
        self.notificationCenter = notificationCenter
        self.streakGapTolerance = streakGapTolerance
    }

    func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let message: String?

        switch settings.authorizationStatus {
        case .notDetermined:
            message = "Ative notificacoes para receber alertas de pausa e distração."
        case .denied:
            message = "As notificacoes estao bloqueadas. Libere no macOS para receber lembretes."
        case .authorized, .provisional, .ephemeral:
            message = nil
        @unknown default:
            message = "O status de notificacoes nao foi reconhecido."
        }

        onPermissionMessage?(message, isAuthorized)
    }

    func requestAuthorization() async {
        do {
            _ = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            onPermissionMessage?("Nao foi possivel solicitar permissao de notificacoes.", false)
            return
        }

        await refreshAuthorizationStatus()
    }

    func evaluate(
        samples: [ActivitySample],
        preferences: MonitoringPreferencesSnapshot,
        classifier: ClassificationEngine
    ) async {
        let activeSamples = samples.sorted { $0.endDate < $1.endDate }
        guard let lastSample = activeSamples.last else { return }

        let lastCategory = classifier.classify(sample: lastSample, preferences: preferences)
        let todayWeekday = Calendar.autoupdatingCurrent.component(.weekday, from: Date())

        for reminder in preferences.reminderProfiles where reminder.isEnabled {
            guard reminder.categoryID == lastCategory.id else { continue }
            guard reminder.weekdays.contains(todayWeekday) else { continue }

            let streak = continuousStreak(
                for: reminder.categoryID,
                samples: activeSamples,
                classifier: classifier,
                preferences: preferences
            )

            guard let streak else { continue }
            guard streak.duration >= TimeInterval(reminder.thresholdMinutes * 60) else { continue }

            if let deliveredAt = lastDeliveredAt[reminder.id], deliveredAt >= streak.startDate {
                continue
            }

            let allowed = await notificationsAllowed()
            guard allowed else { continue }

            await deliver(reminder: reminder, streak: streak, category: lastCategory)
            lastDeliveredAt[reminder.id] = Date()
            onReminderMessage?("Lembrete disparado: \(reminder.title)")
        }
    }

    private func notificationsAllowed() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    private func deliver(
        reminder: ReminderProfile,
        streak: ReminderStreak,
        category: ActivityCategory
    ) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default
        content.subtitle = "\(category.title) por \(LuumFormatters.duration(streak.duration))"

        let request = UNNotificationRequest(
            identifier: "luum-reminder-\(reminder.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        try? await notificationCenter.add(request)
    }

    private func continuousStreak(
        for categoryID: String,
        samples: [ActivitySample],
        classifier: ClassificationEngine,
        preferences: MonitoringPreferencesSnapshot
    ) -> ReminderStreak? {
        guard let lastSample = samples.last else { return nil }
        let lastCategory = classifier.classify(sample: lastSample, preferences: preferences)
        guard lastCategory.id == categoryID else { return nil }

        var streakStart = lastSample.startDate
        var streakEnd = lastSample.endDate

        for sample in samples.dropLast().reversed() {
            let category = classifier.classify(sample: sample, preferences: preferences)
            guard category.id == categoryID else { break }
            guard streakStart.timeIntervalSince(sample.endDate) <= streakGapTolerance else { break }

            streakStart = sample.startDate
            streakEnd = max(streakEnd, sample.endDate)
        }

        return ReminderStreak(startDate: streakStart, endDate: streakEnd)
    }
}

private struct ReminderStreak {
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }
}
