const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const statusPath = require.resolve('../api/auth/[action]');
const upsertPath = statusPath; // merged into auth/[action].js
const checkoutPath = require.resolve('../api/checkout');

function response() {
    return {
        body: null,
        code: 200,
        ended: false,
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
            this.ended = true;
            return this;
        }
    };
}

function installFirebaseAdminMock({ decoded, userExists = true, userData = {}, onSet = () => {}, onGetFirestore = () => {} }) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[statusPath];
    delete require.cache[upsertPath];

    const admin = {
        auth() {
            return {
                async verifyIdToken(token) {
                    assert.equal(token, 'valid-token');
                    return decoded;
                }
            };
        },
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
    };

    const ref = {
        async get() {
            return { exists: userExists, data: () => userData };
        },
        async set(data, options) {
            onSet(data, options);
        }
    };

    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath,
        filename: firebaseAdminPath,
        loaded: true,
        exports: {
            admin,
            getAdminApp() { return {}; },
            getFirestore() {
                onGetFirestore();
                return {
                    collection(name) {
                        assert.equal(name, 'users');
                        return {
                            doc(uid) {
                                assert.equal(uid, decoded.uid);
                                return ref;
                            }
                        };
                    }
                };
            }
        }
    };
}

test('auth status rejects missing Firebase credentials before opening Firestore', async () => {
    let firestoreCalls = 0;
    installFirebaseAdminMock({
        decoded: { uid: 'unused-user' },
        onGetFirestore: () => { firestoreCalls += 1; }
    });

    const handler = require('../api/auth/[action]');
    const res = response();
    await handler({
        method: 'GET',
        query: { action: 'status' },
        headers: { origin: 'https://luum-app.web.app' }
    }, res);

    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Login Firebase obrigatório');
    assert.equal(firestoreCalls, 0);
});

test('checkout rejects missing Firebase credentials before validating the request body', async () => {
    installFirebaseAdminMock({ decoded: { uid: 'unused-user' } });
    delete require.cache[checkoutPath];

    const handler = require('../api/checkout');
    const res = response();
    await handler({
        method: 'POST',
        headers: { origin: 'https://luum-app.web.app' },
        body: {}
    }, res);

    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Login Firebase obrigatório');
});

test('checkout rejects invalid or expired Firebase tokens with 401', async () => {
    installFirebaseAdminMock({ decoded: { uid: 'unused-user' } });
    delete require.cache[checkoutPath];

    const handler = require('../api/checkout');
    const res = response();
    await handler({
        method: 'POST',
        headers: {
            authorization: 'Bearer invalid-token',
            origin: 'https://luum-app.web.app'
        },
        body: { plan: 'essencial', uid: 'unused-user', billing: 'monthly', quantity: 1 }
    }, res);

    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Token Firebase inválido ou expirado');
});

test('checkout rejects UID mismatch between token and request body with 403', async () => {
    installFirebaseAdminMock({ decoded: { uid: 'token-uid' } });
    delete require.cache[checkoutPath];

    const handler = require('../api/checkout');
    const res = response();
    await handler({
        method: 'POST',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: { plan: 'essencial', uid: 'different-uid', billing: 'monthly', quantity: 1 }
    }, res);

    assert.equal(res.code, 403);
    assert.equal(res.body.error, 'Usuário do token não confere com checkout');
});

test('upsert user creates a Firebase account document with trial entitlement', async () => {
    const writes = [];
    installFirebaseAdminMock({
        decoded: {
            uid: 'firebase-user',
            email: 'USER@LUUM.APP',
            name: 'Firebase Name',
            picture: 'https://example.com/avatar.png'
        },
        userExists: false,
        userData: { uid: 'firebase-user', plan: 'essencial' },
        onSet: (data, options) => writes.push({ data, options })
    });

    const handler = require('../api/auth/[action]');
    const res = response();
    await handler({
        method: 'POST',
        query: { action: 'upsert-user' },
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: { name: 'Body Name' }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.ok, true);
    assert.equal(writes.length, 1);
    assert.equal(writes[0].data.uid, 'firebase-user');
    assert.equal(writes[0].data.email, 'user@luum.app');
    assert.equal(writes[0].data.name, 'Firebase Name');
    assert.equal(writes[0].data.plan, 'essencial');
    assert.equal(writes[0].data.role, 'user');
    assert.equal(writes[0].data.subscription.status, 'trial');
    assert.equal(typeof writes[0].data.subscription.trialEndsAt.toMillis, 'function');
    assert.deepEqual(writes[0].options, { merge: true });
});

test('upsert user stores sanitized onboarding without trusting profile body fields', async () => {
    const writes = [];
    installFirebaseAdminMock({
        decoded: {
            uid: 'signup-user',
            email: 'signup@luum.app',
            name: 'Verified Signup',
            picture: 'https://example.com/verified.png'
        },
        userExists: false,
        userData: { uid: 'signup-user', plan: 'essencial' },
        onSet: (data, options) => writes.push({ data, options })
    });

    const handler = require('../api/auth/[action]');
    const res = response();
    await handler({
        method: 'POST',
        query: { action: 'upsert-user' },
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            email: 'spoofed@example.com',
            name: 'Body Name',
            photoURL: 'https://example.com/body.png',
            onboarding: {
                cargo: 'Founder',
                time: '2-5',
                ferramentas: ['Notion', 'Notion', 'ClickUp', '  '],
                objetivo: 'Faturar mais horas'
            }
        }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(writes[0].data.email, 'signup@luum.app');
    assert.equal(writes[0].data.name, 'Verified Signup');
    assert.equal(writes[0].data.photoURL, 'https://example.com/verified.png');
    assert.deepEqual(writes[0].data.onboarding, {
        cargo: 'Founder',
        time: '2-5',
        ferramentas: ['Notion', 'ClickUp'],
        objetivo: 'Faturar mais horas'
    });
    assert.deepEqual(writes[0].data.quiz, writes[0].data.onboarding);
});

test('upsert existing user keeps plan and subscription untouched', async () => {
    const writes = [];
    installFirebaseAdminMock({
        decoded: {
            uid: 'paid-user',
            email: 'paid@luum.app',
            name: 'Paid User'
        },
        userExists: true,
        userData: {
            uid: 'paid-user',
            plan: 'negocios',
            subscription: { status: 'active' },
            role: 'admin'
        },
        onSet: (data, options) => writes.push({ data, options })
    });

    const handler = require('../api/auth/[action]');
    const res = response();
    await handler({
        method: 'POST',
        query: { action: 'upsert-user' },
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: { name: 'Body Name' }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(writes.length, 1);
    assert.equal(Object.prototype.hasOwnProperty.call(writes[0].data, 'plan'), false);
    assert.equal(Object.prototype.hasOwnProperty.call(writes[0].data, 'subscription'), false);
    assert.equal(Object.prototype.hasOwnProperty.call(writes[0].data, 'role'), false);
    assert.deepEqual(writes[0].options, { merge: true });
});

test('upsert user rejects malformed JSON as a client error', async () => {
    const writes = [];
    installFirebaseAdminMock({
        decoded: {
            uid: 'firebase-user',
            email: 'user@luum.app'
        },
        userExists: true,
        userData: { uid: 'firebase-user', plan: 'profissional' },
        onSet: (data, options) => writes.push({ data, options })
    });

    const handler = require('../api/auth/[action]');
    const res = response();
    await handler({
        method: 'POST',
        query: { action: 'upsert-user' },
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: '{"onboarding":'
    }, res);

    assert.equal(res.code, 400);
    assert.equal(res.body.error, 'JSON da conta inválido');
    assert.equal(writes.length, 0);
});

test('auth status returns entitlement from the verified Firebase uid document', async () => {
    const now = Date.now();
    const writes = [];
    installFirebaseAdminMock({
        decoded: { uid: 'paid-user', email: 'paid@luum.app' },
        userData: {
            plan: 'profissional',
            subscription: {
                status: 'active',
                currentPeriodEnd: { toMillis: () => now + 86_400_000 }
            }
        },
        onSet: (data, options) => writes.push({ data, options })
    });

    const handler = require('../api/auth/[action]');
    const res = response();
    const deviceID = 'a'.repeat(64);
    await handler({
        method: 'GET',
        query: { action: 'status' },
        headers: {
            authorization: 'Bearer valid-token',
            'x-luum-device-id': deviceID,
            origin: 'https://luum-app.web.app'
        }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.locked, false);
    assert.equal(res.body.plan, 'profissional');
    assert.equal(res.body.trial, false);
    assert.equal(res.body.expiresAt, now + 86_400_000);
    assert.equal(writes.length, 1);
    assert.equal(writes[0].data.security.lastDeviceID, deviceID);
    assert.deepEqual(writes[0].options, { merge: true });
});

test('auth status ignores malformed device ids', async () => {
    const writes = [];
    installFirebaseAdminMock({
        decoded: { uid: 'paid-user', email: 'paid@luum.app' },
        userData: {
            plan: 'profissional',
            subscription: { status: 'active' }
        },
        onSet: (data, options) => writes.push({ data, options })
    });

    const handler = require('../api/auth/[action]');
    const res = response();
    await handler({
        method: 'GET',
        query: { action: 'status' },
        headers: {
            authorization: 'Bearer valid-token',
            'x-luum-device-id': 'not-a-device',
            origin: 'https://luum-app.web.app'
        }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(writes.length, 0);
});

test('auth status honors stronger legacy onboarding plan for desktop gates', async () => {
    const now = Date.now();
    installFirebaseAdminMock({
        decoded: { uid: 'team-user', email: 'team@luum.app' },
        userData: {
            plan: 'profissional',
            onboarding: {
                plan: 'equipes',
                role: 'admin',
                seats: 1
            },
            subscription: {
                status: 'active',
                currentPeriodEnd: { toMillis: () => now + 86_400_000 }
            }
        }
    });

    const handler = require('../api/auth/[action]');
    const res = response();
    await handler({
        method: 'GET',
        query: { action: 'status' },
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.locked, false);
    assert.equal(res.body.plan, 'equipes');
    assert.equal(res.body.trial, false);
});
