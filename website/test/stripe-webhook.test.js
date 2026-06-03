const test = require('node:test');
const assert = require('node:assert/strict');
const {
    invoiceSubscriptionID,
    invoiceSubscriptionMetadata,
    normalizeStripeStatus
} = require('../api/_stripeWebhookShape');

test('normalizes Stripe trialing subscriptions as active for app entitlement', () => {
    assert.equal(normalizeStripeStatus('trialing'), 'active');
    assert.equal(normalizeStripeStatus('active'), 'active');
    assert.equal(normalizeStripeStatus('past_due'), 'past_due');
});

test('reads subscription id from legacy and current invoice shapes', () => {
    assert.equal(
        invoiceSubscriptionID({ subscription: 'sub_legacy' }),
        'sub_legacy'
    );
    assert.equal(
        invoiceSubscriptionID({
            parent: {
                subscription_details: {
                    subscription: 'sub_current'
                }
            }
        }),
        'sub_current'
    );
});

test('reads subscription metadata from current invoice parent snapshot', () => {
    assert.deepEqual(
        invoiceSubscriptionMetadata({
            parent: {
                subscription_details: {
                    metadata: {
                        uid: 'firebase-user',
                        plan: 'profissional',
                        billing: 'annually'
                    }
                }
            }
        }),
        {
            uid: 'firebase-user',
            plan: 'profissional',
            billing: 'annually'
        }
    );
});
