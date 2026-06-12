const test = require('node:test');
const assert = require('node:assert/strict');
const {
    payloadAccountMatchesFirebaseUID,
    payloadHasAccountUID,
    payloadAccountUID,
    payloadForEntitlement,
    payloadSize,
    sanitizedPayloadForStorage
} = require('../api/_syncPayload');

test('accepts legacy backup payloads without account metadata', () => {
    assert.equal(payloadAccountUID({}), '');
    assert.equal(payloadAccountMatchesFirebaseUID({}, 'firebase-user'), true);
    assert.equal(payloadHasAccountUID({}), false);
});

test('requires backup account uid to match Firebase token uid', () => {
    assert.equal(payloadHasAccountUID({
        account: { uid: 'firebase-user' }
    }), true);
    assert.equal(payloadAccountMatchesFirebaseUID({
        account: { uid: 'firebase-user' }
    }, 'firebase-user'), true);
    assert.equal(payloadAccountMatchesFirebaseUID({
        account: { uid: 'other-user' }
    }, 'firebase-user'), false);
});

test('computes JSON payload size for backup limits', () => {
    assert.equal(payloadSize({ ok: true }), Buffer.byteLength(JSON.stringify({ ok: true }), 'utf8'));
});

test('strips raw activities from restored payloads unless the current plan allows them', () => {
    const payload = {
        schemaVersion: 1,
        rawActivities: [{ appName: 'Private App', duration: 60 }]
    };
    const includesFeature = (entitlement, feature) => entitlement.plan === 'negocios' && feature === 'rawActivityBackup';

    assert.equal(payloadForEntitlement(payload, { plan: 'profissional' }, includesFeature).rawActivities, null);
    assert.deepEqual(
        payloadForEntitlement(payload, { plan: 'negocios' }, includesFeature).rawActivities,
        payload.rawActivities
    );
});

test('sanitizes integration secrets and cached calendar events before storage', () => {
    const payload = {
        monitoringPreferences: {
            zapierSettings: { webhookURL: 'https://hooks.zapier.com/hooks/catch/private' }
        },
        googleCalendarSnapshot: {
            clientID: 'public-client-id',
            clientSecret: 'private-client-secret',
            connections: [{
                id: 'google-account',
                agendaDay: 123,
                agendaItems: [{ title: 'Private event' }],
                legacyTokens: { accessToken: 'access' },
                tokens: { refreshToken: 'refresh' }
            }]
        }
    };

    const sanitized = sanitizedPayloadForStorage(payload);

    assert.equal(sanitized.monitoringPreferences.zapierSettings.webhookURL, '');
    assert.equal(sanitized.googleCalendarSnapshot.clientSecret, '');
    assert.equal(sanitized.googleCalendarSnapshot.connections[0].agendaDay, null);
    assert.deepEqual(sanitized.googleCalendarSnapshot.connections[0].agendaItems, []);
    assert.equal(sanitized.googleCalendarSnapshot.connections[0].legacyTokens, null);
    assert.equal(sanitized.googleCalendarSnapshot.connections[0].tokens, null);
    assert.equal(payload.googleCalendarSnapshot.clientSecret, 'private-client-secret');
});
