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
func zapierSettingsDecodesEmptyLegacyURLAsEmptyArray() throws {
    let json = """
    {
      "isEnabled": false,
      "webhookURL": "   "
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(ZapierSettings.self, from: json)

    #expect(settings.webhooks.isEmpty)
    #expect(!settings.isEnabled)
}

@Test
func zapierSettingsDecodesModernWebhooksArray() throws {
    let json = """
    {
      "isEnabled": true,
      "webhooks": [
        {"id": "11111111-1111-1111-1111-111111111111", "url": "https://hooks.zapier.com/a", "label": "Alpha", "events": ["focus_profile_triggered"]},
        {"id": "22222222-2222-2222-2222-222222222222", "url": "https://hooks.zapier.com/b", "label": "Beta", "events": ["calendar_sync"]}
      ],
      "sendsFocusEvents": true,
      "sendsCalendarSyncEvents": false,
      "sendsWorkspaceRankingEvents": true
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(ZapierSettings.self, from: json)

    #expect(settings.webhooks.count == 2)
    #expect(settings.webhooks[0].url == "https://hooks.zapier.com/a")
    #expect(settings.webhooks[1].label == "Beta")
    #expect(!settings.sendsCalendarSyncEvents)
}

@Test
func zapierSettingsEncodesWithoutWebhookURLField() throws {
    let settings = ZapierSettings(
        isEnabled: true,
        webhooks: [ZapierWebhook(url: "https://hooks.zapier.com/x", label: "X", events: [])],
        sendsFocusEvents: true,
        sendsCalendarSyncEvents: true,
        sendsWorkspaceRankingEvents: false,
        lastDeliveryAt: nil
    )

    let data = try JSONEncoder().encode(settings)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["webhookURL"] == nil)
    #expect(json?["webhooks"] != nil)
    #expect((json?["webhooks"] as? [[String: Any]])?.count == 1)
}

@Test
func zapierSettingsRoundtripPreservesAllWebhooks() throws {
    let original = ZapierSettings(
        isEnabled: true,
        webhooks: [
            ZapierWebhook(url: "https://hooks.zapier.com/1", label: "Um", events: ["focus_profile_triggered"]),
            ZapierWebhook(url: "https://hooks.zapier.com/2", label: "Dois", events: ["calendar_sync", "manual_test"])
        ],
        sendsFocusEvents: false,
        sendsCalendarSyncEvents: true,
        sendsWorkspaceRankingEvents: true,
        lastDeliveryAt: nil
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ZapierSettings.self, from: data)

    #expect(decoded.webhooks.count == 2)
    #expect(decoded.webhooks[0].url == "https://hooks.zapier.com/1")
    #expect(decoded.webhooks[1].events.contains("calendar_sync"))
    #expect(!decoded.sendsFocusEvents)
}

@Test
func zapierSettingsDecodesDefaultsForMissingBoolFields() throws {
    let json = """
    {
      "isEnabled": true,
      "webhooks": []
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(ZapierSettings.self, from: json)

    #expect(settings.sendsFocusEvents)
    #expect(settings.sendsCalendarSyncEvents)
    #expect(settings.sendsWorkspaceRankingEvents)
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
