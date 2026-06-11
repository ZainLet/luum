const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { addNoStoreHeaders } = require('../api/_httpHeaders');
const {
    invoiceSubscriptionID,
    invoiceSubscriptionMetadata,
    normalizeStripeStatus,
    planPatch
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

test('webhook patch only writes official plan values', () => {
    const isValidPlan = (plan) => ['essencial', 'profissional', 'equipes', 'negocios'].includes(plan);

    const valid = planPatch('profissional', isValidPlan);
    assert.equal(valid.plan, 'profissional');

    const invalid = planPatch('enterprise-unlimited', isValidPlan);
    assert.equal(Object.prototype.hasOwnProperty.call(invalid, 'plan'), false);

    const missing = planPatch(undefined, isValidPlan);
    assert.equal(Object.prototype.hasOwnProperty.call(missing, 'plan'), false);
});

test('stripe webhook responses are never cacheable', () => {
    const res = {
        headers: {},
        setHeader(name, value) {
            this.headers[name] = value;
        }
    };

    addNoStoreHeaders(res);
    const webhook = fs.readFileSync(path.join(__dirname, '..', 'api', 'webhook.js'), 'utf8');

    assert.equal(res.headers['Cache-Control'], 'no-store, max-age=0');
    assert.equal(res.headers.Pragma, 'no-cache');
    assert.equal(res.headers.Expires, '0');
    assert.match(webhook, /addNoStoreHeaders\(res\)/);
});
