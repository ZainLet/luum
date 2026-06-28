import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func zapierSettingsDecodesLegacySingularWebhookURL() throws {
    let json = """
    {
      "isEnabled": true,
      "webhookURL": "https://hooks.zapier.com/hooks/catch/legacy"
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(ZapierSettings.self, from: json)

    #expect(settings.isEnabled)
    #expect(settings.webhooks.count == 1)
    #expect(settings.webhooks[0].url == "https://hooks.zapier.com/hooks/catch/legacy")
    #expect(settings.webhooks[0].label == "Webhook")
    #expect(settings.webhookURL == "https://hooks.zapier.com/hooks/catch/legacy")
}

@Test
func zapierSettingsNormalizationPreservesMultipleWebhooksAndCleansLabels() {
    let settings = ZapierSettings(
        isEnabled: true,
        webhooks: [
            ZapierWebhook(
                url: " https://hooks.zapier.com/hooks/catch/focus ",
                label: "  Foco  ",
                events: [.focusProfileTriggered.rawValue]
            ),
            ZapierWebhook(
                url: "https://hooks.zapier.com/hooks/catch/calendar",
                label: " ",
                events: [.calendarSync.rawValue, .manualTest.rawValue]
            ),
        ],
        sendsFocusEvents: true,
        sendsCalendarSyncEvents: true,
        sendsWorkspaceRankingEvents: true,
        lastDeliveryAt: nil
    ).normalized()

    #expect(settings.webhooks.count == 2)
    #expect(settings.webhooks[0].url == "https://hooks.zapier.com/hooks/catch/focus")
    #expect(settings.webhooks[0].label == "Foco")
    #expect(settings.webhooks[1].label == "Webhook")
    #expect(settings.webhooks[1].events == [ZapierEvent.calendarSync.rawValue, ZapierEvent.manualTest.rawValue])
}
#endif
