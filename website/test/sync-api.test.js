const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const syncPath = require.resolve('../api/sync/[backupID].js');

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

function installFirebaseAdminMock({ backupWrites, userPlan = 'profissional', userExists = true, backupExists = true, backupReadData } = {}) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[syncPath];

    const userData = {
        uid: 'firebase-user',
        plan: userPlan,
        subscription: {
            status: 'active',
            currentPeriodEnd: Date.now() + 7 * 24 * 60 * 60 * 1000
        }
    };

    const backupDoc = {
        async set(data, options) {
            if (backupWrites) backupWrites.push({ data, options });
        },
        async get() {
            if (backupReadData) {
                return { exists: true, data: () => backupReadData };
            }
            if (!backupExists) {
                return { exists: false, data: () => null };
            }
            return {
                exists: true,
                data: () => ({
                    payload: backupWrites?.at(-1)?.data.payload || null,
                    updatedAt: { toDate: () => new Date('2026-06-12T00:00:00Z') }
                })
            };
        }
    };

    const userRef = {
        async get() {
            return { exists: userExists, data: () => userData };
        },
        collection(name) {
            assert.equal(name, 'backups');
            return { doc() { return backupDoc; } }
        }
    };

    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath,
        filename: firebaseAdminPath,
        loaded: true,
        exports: {
            admin: {
                auth() {
                    return {
                        async verifyIdToken(token) {
                            assert.equal(token, 'valid-token');
                            return { uid: 'firebase-user' };
                        }
                    };
                },
                firestore: {
                    FieldValue: {
                        serverTimestamp() {
                            return { __serverTimestamp: true };
                        }
                    }
                }
            },
            getFirestore() {
                return {
                    collection(name) {
                        assert.equal(name, 'users');
                        return {
                            doc(uid) {
                                assert.equal(uid, 'firebase-user');
                                return userRef;
                            }
                        };
                    }
                };
            }
        }
    };
}

test('sync API requires Firebase account metadata for new backup writes', async () => {
    const backupWrites = [];
    installFirebaseAdminMock({ backupWrites });

    const handler = require('../api/sync/[backupID].js');
    const res = response();

    await handler({
        method: 'PUT',
        url: '/api/sync/firebase-user',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            payload: {
                schemaVersion: 1,
                monitoringPreferences: {},
                googleCalendarSnapshot: { connections: [] }
            }
        }
    }, res);

    assert.equal(res.code, 400);
    assert.equal(res.body.message, 'Backup atual deve incluir o UID da conta Firebase');
    assert.equal(backupWrites.length, 0);
});

test('sync API rejects malformed JSON as a client error', async () => {
    const backupWrites = [];
    installFirebaseAdminMock({ backupWrites });

    const handler = require('../api/sync/[backupID].js');
    const res = response();

    await handler({
        method: 'PUT',
        url: '/api/sync/firebase-user',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: '{"payload":'
    }, res);

    assert.equal(res.code, 400);
    assert.equal(res.body.message, 'JSON do backup inválido');
    assert.equal(backupWrites.length, 0);
});

test('sync API accepts current backup writes only when account uid matches Firebase token', async () => {
    const backupWrites = [];
    installFirebaseAdminMock({ backupWrites });

    const handler = require('../api/sync/[backupID].js');
    const res = response();

    await handler({
        method: 'PUT',
        url: '/api/sync/firebase-user',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            payload: {
                schemaVersion: 1,
                account: { uid: 'firebase-user', email: 'user@luum.app' },
                monitoringPreferences: {},
                googleCalendarSnapshot: { connections: [] }
            }
        }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(backupWrites.length, 1);
    assert.equal(backupWrites[0].data.uid, 'firebase-user');
    assert.equal(backupWrites[0].data.payload.account.uid, 'firebase-user');
});

test('sync API rejects missing auth with 401', async () => {
    const handler = require('../api/sync/[backupID].js');
    const res = response();

    await handler({
        method: 'PUT',
        url: '/api/sync/firebase-user',
        headers: { origin: 'https://luum-app.web.app' },
        body: {}
    }, res);

    assert.equal(res.code, 401);
    assert.equal(res.body.message, 'Login Firebase obrigatório para backup');
});

test('sync API POST returns 200 with null payload when backup does not exist', async () => {
    installFirebaseAdminMock({ backupExists: false });

    const handler = require('../api/sync/[backupID].js');
    const res = response();

    await handler({
        method: 'POST',
        url: '/api/sync/firebase-user',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {}
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.payload, null);
    assert.equal(res.body.updatedAt, null);
});

test('sync API POST returns 200 with payload and updatedAt when backup exists', async () => {
    const updatedAtDate = new Date('2026-06-22T12:00:00Z');
    installFirebaseAdminMock({
        backupReadData: {
            payload: { schemaVersion: 1, preferences: { theme: 'dark' } },
            updatedAt: { toDate: () => updatedAtDate }
        }
    });

    const handler = require('../api/sync/[backupID].js');
    const res = response();

    await handler({
        method: 'POST',
        url: '/api/sync/firebase-user',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {}
    }, res);

    assert.equal(res.code, 200);
    assert.deepEqual(res.body.payload, { schemaVersion: 1, preferences: { theme: 'dark' }, rawActivities: null });
    const expectedSeconds = updatedAtDate.getTime() / 1000 - 978307200;
    assert.equal(res.body.updatedAt, expectedSeconds);
});

test('sync API PUT rejects cloud backup for essencial plan with 403', async () => {
    installFirebaseAdminMock({ userPlan: 'essencial' });

    const handler = require('../api/sync/[backupID].js');
    const res = response();

    await handler({
        method: 'PUT',
        url: '/api/sync/firebase-user',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            payload: {
                account: { uid: 'firebase-user', email: 'user@luum.app' },
                preferences: {}
            }
        }
    }, res);

    assert.equal(res.code, 403);
    assert.equal(res.body.message, 'Seu plano não permite backup Firebase');
});

test('sync API PUT rejects payload larger than 1 MB with 413', async () => {
    const backupWrites = [];
    installFirebaseAdminMock({ backupWrites });

    const handler = require('../api/sync/[backupID].js');
    const res = response();
    const largeArray = new Array(500_000).fill('x');

    await handler({
        method: 'PUT',
        url: '/api/sync/firebase-user',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            payload: {
                schemaVersion: 1,
                account: { uid: 'firebase-user', email: 'user@luum.app' },
                data: largeArray
            }
        }
    }, res);

    assert.equal(res.code, 413);
    assert.equal(res.body.message, 'Backup excede o limite de 1 MB');
    assert.equal(backupWrites.length, 0);
});

test('sync API PUT rejects rawActivities without negocios plan with 403', async () => {
    installFirebaseAdminMock({ userPlan: 'profissional' });

    const handler = require('../api/sync/[backupID].js');
    const res = response();

    await handler({
        method: 'PUT',
        url: '/api/sync/firebase-user',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            payload: {
                account: { uid: 'firebase-user', email: 'user@luum.app' },
                preferences: {},
                rawActivities: [{ app: 'Xcode', duration: 3600 }]
            }
        }
    }, res);

    assert.equal(res.code, 403);
    assert.equal(res.body.message, 'Atividades brutas exigem o plano Negócios');
});
