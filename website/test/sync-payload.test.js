const test = require('node:test');
const assert = require('node:assert/strict');
const {
    payloadAccountMatchesFirebaseUID,
    payloadAccountUID,
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
