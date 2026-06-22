const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const stripePath = require.resolve('../api/_stripe');
const webhookPath = require.resolve('../api/webhook');

function response() {
    return {
        body: null,
        code: 200,
        ended: false,
        headers: {},
        sent: null,
        setHeader(name, value) {
            this.headers[name] = value;
        },
        status(code) {
            this.code = code;
            return this;
        },
        json(body) {
            this.body = body;
            return this;
        },
        send(body) {
            this.sent = body;
            return this;
        },
        end() {
            this.ended = true;
            return this;
        }
    };
}

function installWebhookMocks({ event, writes }) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[stripePath];
    delete require.cache[webhookPath];

    const existingEvents = {};
    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath,
        filename: firebaseAdminPath,
        loaded: true,
        exports: {
            admin: {
                firestore: {
                    FieldValue: {
                        serverTimestamp() {
                            return { __serverTimestamp: true };
                        }
                    },
                    Timestamp: {
                        fromMillis(millis) {
                            return { __millis: millis, toMillis: () => millis };
                        }
                    }
                }
            },
            getFirestore() {
                return {
                    collection(name) {
                        if (name === '_webhookEvents') {
                            return {
                                doc(eventId) {
                                    return {
                                        async get() {
                                            if (existingEvents[eventId]) {
                                                return { exists: true, data: () => existingEvents[eventId] };
                                            }
                                            return { exists: false, data: () => null };
                                        },
                                        async set(data) {
                                            existingEvents[eventId] = data;
                                        }
                                    };
                                }
                            };
                        }
                        assert.equal(name, 'users');
                        return {
                            doc(uid) {
                                assert.equal(uid, 'firebase-user');
                                return {
                                    async set(data, options) {
                                        writes.push({ data, options });
                                    }
                                };
                            }
                        };
                    }
                };
            }
        }
    };

    const stripe = {
        webhooks: {
            constructEvent(rawBody, signature, secret) {
                assert.equal(signature, 'stripe-signature');
                assert.equal(secret, 'whsec_test');
                assert.equal(Buffer.isBuffer(rawBody), true);
                return event;
            }
        },
        subscriptions: {
            async retrieve(subscriptionID) {
                assert.equal(subscriptionID, 'sub_123ABC');
                return {
                    id: subscriptionID,
                    status: 'active',
                    cancel_at_period_end: false,
                    current_period_start: 1_750_000_000,
                    current_period_end: 1_752_592_000,
                    metadata: {
                        uid: 'firebase-user',
                        plan: 'profissional',
                        billing: 'monthly'
                    },
                    items: {
                        data: [{
                            quantity: 1,
                            price: {
                                recurring: { interval: 'month' }
                            }
                        }]
                    }
                };
            }
        }
    };

    require.cache[stripePath] = {
        id: stripePath,
        filename: stripePath,
        loaded: true,
        exports: {
            getStripe: async () => stripe,
            isStripePlan: (plan) => ['essencial', 'profissional', 'equipes', 'negocios'].includes(plan),
            requireSetting: async (name) => {
                assert.equal(name, 'STRIPE_WEBHOOK_SECRET');
                return 'whsec_test';
            }
        }
    };
}

test('stripe checkout webhook writes the official plan and subscription snapshot', async () => {
    const writes = [];
    installWebhookMocks({
        writes,
        event: {
            type: 'checkout.session.completed',
            data: {
                object: {
                    id: 'cs_test_123',
                    customer: 'cus_123',
                    subscription: 'sub_123ABC',
                    metadata: {
                        uid: 'firebase-user',
                        plan: 'profissional',
                        billing: 'monthly'
                    }
                }
            }
        }
    });

    const handler = require('../api/webhook');
    const res = response();

    await handler({
        method: 'POST',
        headers: { 'stripe-signature': 'stripe-signature' },
        body: Buffer.from('{}')
    }, res);

    assert.equal(res.code, 200);
    assert.deepEqual(res.body, { received: true });
    assert.equal(writes.length, 1);
    assert.equal(writes[0].data.plan, 'profissional');
    assert.equal(writes[0].data.subscription.status, 'active');
    assert.equal(writes[0].data.subscription.stripeCustomerId, 'cus_123');
    assert.equal(writes[0].data.subscription.stripeSubscriptionId, 'sub_123ABC');
    assert.equal(writes[0].data.subscription.stripeSessionId, 'cs_test_123');
    assert.equal(writes[0].data.subscription.billing, 'monthly');
    assert.equal(writes[0].data.subscription.quantity, 1);
    assert.equal(writes[0].data.subscription.currentPeriodStart.toMillis(), 1_750_000_000_000);
    assert.equal(writes[0].data.subscription.currentPeriodEnd.toMillis(), 1_752_592_000_000);
    assert.deepEqual(writes[0].options, { merge: true });
});

test('stripe webhook skips already processed events (replay protection)', async () => {
    const writes = [];
    const existingEvents = {};
    installWebhookMocks({
        writes,
        event: {
            id: 'evt_replay_001',
            type: 'checkout.session.completed',
            data: {
                object: {
                    id: 'cs_test_456',
                    customer: 'cus_456',
                    subscription: 'sub_456ABC',
                    metadata: {
                        uid: 'firebase-user',
                        plan: 'essencial',
                        billing: 'monthly'
                    }
                }
            }
        }
    });

    delete require.cache[firebaseAdminPath];
    delete require.cache[stripePath];
    delete require.cache[webhookPath];

    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath,
        filename: firebaseAdminPath,
        loaded: true,
        exports: {
            admin: {
                firestore: {
                    FieldValue: {
                        serverTimestamp() {
                            return { __serverTimestamp: true };
                        }
                    },
                    Timestamp: {
                        fromMillis(millis) {
                            return { __millis: millis, toMillis: () => millis };
                        }
                    }
                }
            },
            getFirestore() {
                return {
                    collection(name) {
                        if (name === '_webhookEvents') {
                            return {
                                doc(eventId) {
                                    return {
                                        async get() {
                                            if (existingEvents[eventId]) {
                                                return { exists: true, data: () => existingEvents[eventId] };
                                            }
                                            return { exists: false, data: () => null };
                                        },
                                        async set(data) {
                                            existingEvents[eventId] = data;
                                        }
                                    };
                                }
                            };
                        }
                        if (name === 'users') {
                            return {
                                doc(uid) {
                                    assert.equal(uid, 'firebase-user');
                                    return {
                                        async set(data, options) {
                                            writes.push({ data, options });
                                        }
                                    };
                                }
                            };
                        }
                        return {};
                    }
                };
            }
        }
    };

    require.cache[stripePath] = {
        id: stripePath,
        filename: stripePath,
        loaded: true,
        exports: {
            getStripe: async () => ({
                webhooks: {
                    constructEvent(rawBody, signature, secret) {
                        return { id: 'evt_replay_001', type: 'checkout.session.completed', data: { object: {
                            id: 'cs_test_456', customer: 'cus_456', subscription: 'sub_456ABC',
                            metadata: { uid: 'firebase-user', plan: 'essencial', billing: 'monthly' }
                        } } };
                    }
                },
                subscriptions: {
                    async retrieve() {
                        return {
                            id: 'sub_456ABC', status: 'active', cancel_at_period_end: false,
                            current_period_start: 1_750_000_000, current_period_end: 1_752_592_000,
                            metadata: { uid: 'firebase-user', plan: 'essencial', billing: 'monthly' },
                            items: { data: [{ quantity: 1, price: { recurring: { interval: 'month' } } }] }
                        };
                    }
                }
            }),
            isStripePlan: (plan) => ['essencial', 'profissional', 'equipes', 'negocios'].includes(plan),
            requireSetting: async () => 'whsec_test'
        }
    };

    const handler = require('../api/webhook');

    // First call — should process and write
    const res1 = response();
    await handler({
        method: 'POST',
        headers: { 'stripe-signature': 'stripe-signature' },
        body: Buffer.from('{}')
    }, res1);
    assert.equal(res1.code, 200);
    assert.equal(res1.body.received, true);
    assert.equal(res1.body.deduplicated, undefined);
    assert.equal(writes.length, 1);

    // Second call with same event ID — should be skipped (deduplicated)
    const res2 = response();
    await handler({
        method: 'POST',
        headers: { 'stripe-signature': 'stripe-signature' },
        body: Buffer.from('{}')
    }, res2);
    assert.equal(res2.code, 200);
    assert.equal(res2.body.received, true);
    assert.equal(res2.body.deduplicated, true);
    assert.equal(writes.length, 1); // no additional write
});
