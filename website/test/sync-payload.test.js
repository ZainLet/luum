const test = require('node:test');
const assert = require('node:assert/strict');
const {
    payloadAccountMatchesFirebaseUID,
    payloadAccountUID,
    payloadForEntitlement,
    payloadSize
} = require('../api/_syncPayload');

test('accepts legacy backup payloads without account metadata', () => {
    assert.equal(payloadAccountUID({}), '');
    assert.equal(payloadAccountMatchesFirebaseUID({}, 'firebase-user'), true);
});

test('requires backup account uid to match Firebase token uid', () => {
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
