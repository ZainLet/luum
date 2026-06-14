const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const rankingPath = require.resolve('../api/workspaces/[workspaceID]/ranking');

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

function installFirebaseAdminMock() {
    delete require.cache[firebaseAdminPath];
    delete require.cache[rankingPath];

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
                            return { uid: 'team-user' };
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
                                assert.equal(uid, 'team-user');
                                return {
                                    async get() {
                                        return {
                                            exists: true,
                                            data: () => ({
                                                plan: 'equipes',
                                                subscription: {
                                                    status: 'active',
                                                    currentPeriodEnd: Date.now() + 86_400_000
                                                }
                                            })
                                        };
                                    }
                                };
                            }
                        };
                    }
                };
            }
        }
    };
}

test('workspace ranking rejects malformed JSON as a client error', async () => {
    installFirebaseAdminMock();

    const handler = require('../api/workspaces/[workspaceID]/ranking');
    const res = response();

    await handler({
        method: 'POST',
        url: '/api/workspaces/team-space/ranking',
        query: { workspaceID: 'team-space' },
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: '{"workspaceSecret":'
    }, res);

    assert.equal(res.code, 400);
    assert.equal(res.body.message, 'JSON do workspace inválido');
});
