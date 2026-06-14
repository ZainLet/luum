const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const adminAuthPath = require.resolve('../api/_adminAuth');
const adminActionsPath = require.resolve('../api/_adminActions');

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

function installFirebaseAdminMock({ writes, firestoreData }) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[adminAuthPath];
    delete require.cache[adminActionsPath];

    const userRecord = {
        uid: 'target-user',
        email: 'target@luum.app',
        displayName: 'Target User',
        customClaims: {}
    };

    const admin = {
        auth() {
            return {
                async verifyIdToken(token) {
                    assert.equal(token, 'valid-token');
                    return {
                        uid: 'admin-user',
                        email: 'oluum.app@gmail.com'
                    };
                },
                async getUser(uid) {
                    assert.equal(uid, userRecord.uid);
                    return userRecord;
                }
            };
        },
        firestore: {
            FieldValue: {
                serverTimestamp() {
                    return { __serverTimestamp: true };
                },
                delete() {
                    return { __delete: true };
                }
            }
        }
    };

    const ref = {
        async get() {
            return { exists: true, data: () => firestoreData };
        },
        async set(data, options) {
            writes.push({ data, options });
            firestoreData.security = {
                devicesClearedAt: data['security.devicesClearedAt'],
                devicesClearedBy: data['security.devicesClearedBy'],
                devicesClearedByEmail: data['security.devicesClearedByEmail']
            };
        }
    };

    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath,
        filename: firebaseAdminPath,
        loaded: true,
        exports: {
            admin,
            getAdminApp() {
                return {};
            },
            getFirestore() {
                return {
                    collection(name) {
                        assert.equal(name, 'users');
                        return {
                            doc(uid) {
                                assert.equal(uid, userRecord.uid);
                                return ref;
                            }
                        };
                    }
                };
            }
        }
    };
}

test('admin clearDevices action deletes tracked device fields without changing plan', async () => {
    const writes = [];
    const firestoreData = {
        plan: 'profissional',
        subscription: { status: 'active' },
        security: {
            devices: {
                ['a'.repeat(64)]: { firstSeenAt: 'old' }
            },
            lastDeviceID: 'a'.repeat(64),
            lastDeviceSeenAt: 'old'
        }
    };
    installFirebaseAdminMock({ writes, firestoreData });

    const { adminUsersHandler } = require('../api/_adminActions');
    const res = response();
    await adminUsersHandler({
        method: 'POST',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            uid: 'target-user',
            action: 'clearDevices'
        }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.user.plan, 'profissional');
    assert.equal(res.body.user.security.deviceCount, 0);
    assert.equal(writes.length, 1);
    assert.deepEqual(writes[0].options, { merge: true });
    assert.deepEqual(writes[0].data['security.devices'], { __delete: true });
    assert.deepEqual(writes[0].data['security.lastDeviceID'], { __delete: true });
    assert.deepEqual(writes[0].data['security.lastDeviceSeenAt'], { __delete: true });
    assert.equal(writes[0].data['security.devicesClearedBy'], 'admin-user');
    assert.equal(writes[0].data['security.devicesClearedByEmail'], 'oluum.app@gmail.com');
    assert.equal(Object.hasOwn(writes[0].data, 'plan'), false);
    assert.equal(Object.hasOwn(writes[0].data, 'subscription'), false);
});

test('admin users action rejects malformed JSON as a client error', async () => {
    const writes = [];
    const firestoreData = {
        plan: 'profissional',
        subscription: { status: 'active' },
        security: {}
    };
    installFirebaseAdminMock({ writes, firestoreData });

    const { adminUsersHandler } = require('../api/_adminActions');
    const res = response();
    await adminUsersHandler({
        method: 'POST',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: '{"uid":'
    }, res);

    assert.equal(res.code, 400);
    assert.equal(res.body.error, 'JSON do admin inválido');
    assert.equal(writes.length, 0);
});

test('admin integrations action rejects malformed JSON as a client error', async () => {
    const writes = [];
    const firestoreData = {
        plan: 'profissional',
        subscription: { status: 'active' },
        security: {}
    };
    installFirebaseAdminMock({ writes, firestoreData });

    const { integrationsHandler } = require('../api/_adminActions');
    const res = response();
    await integrationsHandler({
        method: 'POST',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: '{"updates":'
    }, res);

    assert.equal(res.code, 400);
    assert.equal(res.body.error, 'JSON do admin inválido');
});
