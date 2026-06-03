const test = require('node:test');
const assert = require('node:assert/strict');
const {
    STRIPE_SUBSCRIPTION_FIELDS,
    manualSubscriptionSnapshot,
    stripeSubscriptionDeletePatch
} = require('../api/_manualGrant');

test('manual grant snapshot is clearly separated from Stripe billing', () => {
    const snapshot = manualSubscriptionSnapshot({
        status: 'active',
        seats: 3,
        currentPeriodEnd: 'period-end',
        adminUser: { uid: 'admin-user', email: 'oluum.app@gmail.com' },
        serverTimestamp: 'server-now'
    });

    assert.deepEqual(snapshot, {
        status: 'active',
        source: 'manual',
        seats: 3,
        quantity: 3,
        billing: 'manual',
        currentPeriodEnd: 'period-end',
        updatedAt: 'server-now',
        grantedAt: 'server-now',
        grantedBy: 'admin-user',
        grantedByEmail: 'oluum.app@gmail.com'
    });
});

test('manual trial grant mirrors period end into trial end', () => {
    const snapshot = manualSubscriptionSnapshot({
        status: 'trial',
        seats: 1,
        currentPeriodEnd: 'trial-end',
        adminUser: { uid: 'admin-user' },
        serverTimestamp: 'server-now'
    });

    assert.equal(snapshot.trialEndsAt, 'trial-end');
    assert.equal(snapshot.grantedByEmail, null);
});

test('manual grants delete every stale Stripe subscription field', () => {
    const patch = stripeSubscriptionDeletePatch('__delete__');

    assert.deepEqual(Object.keys(patch).sort(), STRIPE_SUBSCRIPTION_FIELDS
        .map((field) => `subscription.${field}`)
        .sort());
    assert.equal(patch['subscription.stripeSubscriptionId'], '__delete__');
});
