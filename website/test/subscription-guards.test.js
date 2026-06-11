const test = require('node:test');
const assert = require('node:assert/strict');
const { cancellableStripeSubscriptionID } = require('../api/_subscriptionGuards');

test('does not cancel manually granted subscriptions through Stripe', () => {
    assert.equal(cancellableStripeSubscriptionID({
        subscription: {
            source: 'manual',
            stripeSubscriptionId: 'sub_should_not_cancel'
        }
    }), '');
});

test('accepts only valid Stripe subscription ids for cancellation', () => {
    assert.equal(cancellableStripeSubscriptionID({
        subscription: {
            source: 'stripe',
            stripeSubscriptionId: 'sub_123ABC'
        }
    }), 'sub_123ABC');
    assert.equal(cancellableStripeSubscriptionID({
        subscription: {
            stripeSubscriptionId: 'not-a-subscription-id'
        }
    }), '');
});
