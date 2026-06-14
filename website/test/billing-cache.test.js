const test = require('node:test');
const assert = require('node:assert/strict');

function response() {
    return {
        body: null,
        code: 200,
        headers: {},
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
        end() {
            return this;
        }
    };
}

function assertNoStore(res) {
    assert.equal(res.headers['Cache-Control'], 'no-store, max-age=0');
    assert.equal(res.headers.Pragma, 'no-cache');
    assert.equal(res.headers.Expires, '0');
}

function mockModule(path, exports) {
    const resolved = require.resolve(path);
    delete require.cache[resolved];
    require.cache[resolved] = {
        id: resolved,
        filename: resolved,
        loaded: true,
        exports
    };
    return resolved;
}

function clearModules(paths) {
    paths.forEach((path) => {
        delete require.cache[require.resolve(path)];
    });
}

test('checkout responses are never cacheable', async () => {
    const handler = require('../api/checkout');
    const res = response();

    await handler({
        method: 'POST',
        headers: { origin: 'https://luum-app.web.app' },
        body: { plan: 'invalid-plan', uid: 'firebase-user' }
    }, res);

    assert.equal(res.code, 400);
    assertNoStore(res);
});

test('successful checkout responses are never cacheable', async () => {
    let checkoutSessionOptions = null;
    const touchedModules = [
        '../api/_firebaseAdmin',
        '../api/_stripe',
        '../api/_integrationSettings',
        '../api/checkout'
    ];
    clearModules(touchedModules);
    mockModule('../api/_firebaseAdmin', {
        admin: {
            auth() {
                return {
                    async verifyIdToken() {
                        return { uid: 'firebase-user', email: 'user@luum.app' };
                    }
                };
            }
        },
        getAdminApp() {
            return {};
        }
    });
    mockModule('../api/_stripe', {
        getStripe: async () => ({
            checkout: {
                sessions: {
                    create: async (options) => {
                        checkoutSessionOptions = options;
                        return { id: 'cs_test_luum', url: 'https://checkout.stripe.test/session' };
                    }
                }
            }
        }),
        getPriceID: async () => 'price_test_essencial',
        isStripePlan: (plan) => plan === 'essencial',
        minimumQuantity: () => 1
    });
    mockModule('../api/_integrationSettings', {
        getSetting: async () => 'https://luum-app.web.app'
    });

    const handler = require('../api/checkout');
    const res = response();

    await handler({
        method: 'POST',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            plan: 'essencial',
            uid: 'firebase-user',
            billing: 'monthly',
            quantity: 1,
            email: 'attacker@example.com'
        }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.id, 'cs_test_luum');
    assert.equal(checkoutSessionOptions.customer_email, 'user@luum.app');
    assert.equal(checkoutSessionOptions.metadata.uid, 'firebase-user');
    assert.equal(checkoutSessionOptions.metadata.plan, 'essencial');
    assertNoStore(res);
    clearModules(touchedModules);
});

test('subscription cancellation responses are never cacheable', async () => {
    const handler = require('../api/cancel-subscription');
    const res = response();

    await handler({
        method: 'POST',
        headers: { origin: 'https://luum-app.web.app' },
        body: {}
    }, res);

    assert.equal(res.code, 401);
    assertNoStore(res);
});

test('successful subscription cancellation responses are never cacheable', async () => {
    const touchedModules = [
        '../api/_firebaseAdmin',
        '../api/_stripe',
        '../api/cancel-subscription'
    ];
    clearModules(touchedModules);
    mockModule('../api/_firebaseAdmin', {
        admin: {
            auth() {
                return {
                    async verifyIdToken() {
                        return { uid: 'firebase-user' };
                    }
                };
            },
            firestore: {
                Timestamp: {
                    fromMillis: (millis) => ({ millis })
                },
                FieldValue: {
                    serverTimestamp: () => ({ serverTimestamp: true })
                }
            }
        },
        getFirestore() {
            return {
                collection() {
                    return {
                        doc() {
                            return {
                                async get() {
                                    return {
                                        exists: true,
                                        data: () => ({
                                            subscription: {
                                                status: 'active',
                                                stripeSubscriptionId: 'sub_testluum'
                                            }
                                        })
                                    };
                                },
                                async set() {}
                            };
                        }
                    };
                }
            };
        }
    });
    mockModule('../api/_stripe', {
        getStripe: async () => ({
            subscriptions: {
                update: async () => ({
                    id: 'sub_testluum',
                    current_period_end: 1_800_000_000
                })
            }
        })
    });

    const handler = require('../api/cancel-subscription');
    const res = response();

    await handler({
        method: 'POST',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {}
    }, res);

    assert.equal(res.code, 200);
    assert.deepEqual(res.body, { ok: true, cancelAtPeriodEnd: true });
    assertNoStore(res);
    clearModules(touchedModules);
});
