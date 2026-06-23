const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const workspacePath = require.resolve('../api/_workspace');
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

function installFirebaseAdminMock({
    workspaceData = null,
    membersData = []
} = {}) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[workspacePath];
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
                        if (name === 'users') {
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
                        if (name === 'workspaces') {
                            return {
                                doc(workspaceID) {
                                    return {
                                        async get() {
                                            if (workspaceData) {
                                                return { exists: true, data: () => workspaceData };
                                            }
                                            return { exists: false, data: () => null };
                                        },
                                        collection(sub) {
                                            assert.equal(sub, 'members');
                                            return {
                                                orderBy(field, dir) {
                                                    assert.equal(field, 'score');
                                                    assert.equal(dir, 'desc');
                                                    return {
                                                        limit(n) {
                                                            assert.equal(n, 200);
                                                            return {
                                                                async get() {
                                                                    return {
                                                                        docs: membersData.map((data, i) => ({
                                                                            id: data.id || `member-${i}`,
                                                                            data: () => {
                                                                                const { id, ...rest } = data;
                                                                                return rest;
                                                                            }
                                                                        }))
                                                                    };
                                                                }
                                                            };
                                                        }
                                                    };
                                                }
                                            };
                                        }
                                    };
                                }
                            };
                        }
                        return {};
                    },
                    runTransaction(callback) {
                        const transaction = {
                            async get() {
                                if (workspaceData) {
                                    return { exists: true, data: () => workspaceData };
                                }
                                return { exists: false, data: () => null };
                            },
                            set() {
                                // no-op in mock
                            }
                        };
                        return callback(transaction);
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

test('workspace ranking rejects invalid workspace ID with 400', async () => {
    const handler = require('../api/workspaces/[workspaceID]/ranking');
    const res = response();

    await handler({
        method: 'POST',
        url: '/api/workspaces/../../etc/ranking',
        query: { workspaceID: '../../etc' },
        headers: { origin: 'https://luum-app.web.app' },
        body: {}
    }, res);

    assert.equal(res.code, 400);
    assert.equal(res.body.message, 'Workspace ID inválido');
});

test('workspace ranking rejects missing auth with 401', async () => {
    const handler = require('../api/workspaces/[workspaceID]/ranking');
    const res = response();

    await handler({
        method: 'POST',
        url: '/api/workspaces/team-space/ranking',
        query: { workspaceID: 'team-space' },
        headers: { origin: 'https://luum-app.web.app' },
        body: {}
    }, res);

    assert.equal(res.code, 401);
    assert.equal(res.body.message, 'Login Firebase obrigatório para workspace');
});

test('workspace ranking rejects wrong workspace secret with 403', async () => {
    const crypto = require('node:crypto');
    const validHash = crypto.createHash('sha256').update('valid-secret', 'utf8').digest('hex');
    installFirebaseAdminMock({
        workspaceData: {
            organizationName: 'Minha empresa',
            secretHash: validHash,
            updatedAt: { toDate: () => new Date('2026-06-22T12:00:00Z') }
        },
        membersData: []
    });

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
        body: { workspaceSecret: 'wrong-secret' }
    }, res);

    assert.equal(res.code, 403);
    assert.equal(res.body.message, 'Chave do workspace inválida');
});

test('workspace ranking returns empty entries for workspace with 0 members', async () => {
    const crypto = require('node:crypto');
    const validHash = crypto.createHash('sha256').update('valid-secret', 'utf8').digest('hex');
    installFirebaseAdminMock({
        workspaceData: {
            organizationName: 'Minha empresa',
            secretHash: validHash,
            updatedAt: { toDate: () => new Date('2026-06-22T12:00:00Z') }
        },
        membersData: []
    });

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
        body: { workspaceSecret: 'valid-secret' }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.organizationName, 'Minha empresa');
    assert.deepEqual(res.body.entries, []);
});

test('workspace ranking sanitizes invalid numeric fields', async () => {
    const crypto = require('node:crypto');
    const validHash = crypto.createHash('sha256').update('valid-secret', 'utf8').digest('hex');
    installFirebaseAdminMock({
        workspaceData: {
            organizationName: 'Minha empresa',
            secretHash: validHash,
            updatedAt: { toDate: () => new Date('2026-06-22T12:00:00Z') }
        },
        membersData: [
            { id: 'user-1', memberDisplayName: 'Alice', roleLabel: 'Dev', trackedTime: 'invalido', score: null, contextSwitches: -5, focusTime: 3600, plannedTime: 1800 },
            { id: 'user-2', memberDisplayName: 'Bob', roleLabel: 'Dev', trackedTime: 7200, score: 150, contextSwitches: 3, focusTime: 'nope', plannedTime: 2400 }
        ]
    });

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
        body: { workspaceSecret: 'valid-secret' }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.entries.length, 2);

    // Alice: trackedTime='invalido' → 0, score=null → 0, contextSwitches=-5 → 0
    assert.equal(res.body.entries[0].trackedTime, 0);
    assert.equal(res.body.entries[0].score, 0);
    assert.equal(res.body.entries[0].contextSwitches, 0);

    // Bob: score=150 → clamped to 100
    assert.equal(res.body.entries[1].score, 100);
});

test('workspace ranking marks isCurrentUser correctly', async () => {
    const crypto = require('node:crypto');
    const validHash = crypto.createHash('sha256').update('valid-secret', 'utf8').digest('hex');
    installFirebaseAdminMock({
        workspaceData: {
            organizationName: 'Minha empresa',
            secretHash: validHash,
            updatedAt: { toDate: () => new Date('2026-06-22T12:00:00Z') }
        },
        membersData: [
            { id: 'team-user', memberDisplayName: 'Current', roleLabel: 'Admin', trackedTime: 5000, score: 80, contextSwitches: 2, focusTime: 3000, plannedTime: 2000 },
            { id: 'other-user', memberDisplayName: 'Other', roleLabel: 'Membro', trackedTime: 3000, score: 60, contextSwitches: 5, focusTime: 1500, plannedTime: 1000 }
        ]
    });

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
        body: { workspaceSecret: 'valid-secret' }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.entries.length, 2);

    const currentUser = res.body.entries.find((e) => e.id === 'team-user');
    const otherUser = res.body.entries.find((e) => e.id === 'other-user');
    assert.equal(currentUser.isCurrentUser, true);
    assert.equal(otherUser.isCurrentUser, false);
});
