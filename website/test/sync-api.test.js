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

function installFirebaseAdminMock({ backupWrites }) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[syncPath];

    const userData = {
        uid: 'firebase-user',
        plan: 'profissional',
        subscription: {
            status: 'active',
            currentPeriodEnd: Date.now() + 7 * 24 * 60 * 60 * 1000
        }
    };

    const userRef = {
        async get() {
            return { exists: true, data: () => userData };
        },
        collection(name) {
            assert.equal(name, 'backups');
            return {
                doc(backupID) {
                    assert.equal(backupID, 'firebase-user');
                    return {
                        async set(data, options) {
                            backupWrites.push({ data, options });
                        },
                        async get() {
                            return {
                                exists: true,
                                data: () => ({
                                    payload: backupWrites.at(-1)?.data.payload || null,
                                    updatedAt: { toDate: () => new Date('2026-06-12T00:00:00Z') }
                                })
                            };
                        }
                    };
                }
            };
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
