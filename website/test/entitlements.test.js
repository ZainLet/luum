const test = require('node:test');
const assert = require('node:assert/strict');
const { entitlementForUser, includesFeature, normalizedPlan } = require('../api/_entitlements');

const DAY_MS = 24 * 60 * 60 * 1000;
const now = 1_780_000_000_000;
const timestamp = (millis) => ({ toMillis: () => millis });

test('normalizes external plan aliases', () => {
    assert.equal(normalizedPlan('Profissional'), 'profissional');
    assert.equal(normalizedPlan('business'), 'negocios');
    assert.equal(normalizedPlan('unknown'), 'essencial');
});

test('permits cloud backup during an active trial without permitting raw activity backup', () => {
    const entitlement = entitlementForUser({
        createdAt: timestamp(now - DAY_MS),
        subscription: { status: 'trial', trialEndsAt: timestamp(now + DAY_MS) }
    }, now);

    assert.equal(entitlement.locked, false);
    assert.equal(entitlement.trial, true);
    assert.equal(includesFeature(entitlement, 'cloudBackup'), true);
    assert.equal(includesFeature(entitlement, 'rawActivityBackup'), false);
});

test('rejects expired subscriptions', () => {
    const entitlement = entitlementForUser({
        plan: 'negocios',
        subscription: { status: 'active', currentPeriodEnd: timestamp(now - 1) }
    }, now);

    assert.equal(entitlement.locked, true);
    assert.equal(entitlement.reason, 'expired');
    assert.equal(includesFeature(entitlement, 'cloudBackup'), false);
});

test('enforces plan tiers for Firebase backup', () => {
    const active = (plan) => entitlementForUser({
        plan,
        subscription: { status: 'active', currentPeriodEnd: timestamp(now + DAY_MS) }
    }, now);

    assert.equal(includesFeature(active('essencial'), 'cloudBackup'), false);
    assert.equal(includesFeature(active('profissional'), 'cloudBackup'), true);
    assert.equal(includesFeature(active('equipes'), 'teamWorkspace'), true);
    assert.equal(includesFeature(active('equipes'), 'rawActivityBackup'), false);
    assert.equal(includesFeature(active('negocios'), 'rawActivityBackup'), true);
});
