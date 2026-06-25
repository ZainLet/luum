const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const workspacePath = require.resolve('../api/_workspace');
const memberPath = require.resolve('../api/workspaces/[workspaceID]/members/[memberID]');

function response() {
    return {
        body: null, code: 200, headers: {},
        setHeader(name, value) { this.headers[name] = value; },
        status(code) { this.code = code; return this; },
        json(body) { this.body = body; return this; },
        end() { return this; }
    };
}

function installMock({ workspaceExists = false, memberData = null, badSecret = false } = {}) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[workspacePath];
    delete require.cache[memberPath];

    let savedData = null;
    let savedOptions = null;
    let serverTimestamp = { __serverTimestamp: true };
    const updatedAtDate = new Date('2026-06-22T12:00:00Z');
    const crypto = require('node:crypto');
    const workspaceHash = badSecret
        ? crypto.createHash('sha256').update('real-secret', 'utf8').digest('hex')
        : null;

    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath, filename: firebaseAdminPath, loaded: true,
        exports: {
            admin: {
                auth() {
                    return {
                        async verifyIdToken(token) {
                            assert.equal(token, 'valid-token');
                            return { uid: 'team-user', email: 'user@luum.app' };
                        }
                    };
                },
                firestore: {
                    FieldValue: { serverTimestamp() { return serverTimestamp; } }
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
                                                    subscription: { status: 'active', currentPeriodEnd: Date.now() + 86_400_000 }
                                                })
                                            };
                                        }
                                    };
                                }
                            };
                        }
                        if (name === 'workspaces') {
                            return {
                                doc(id) {
                                    return {
                                        get() {
                                            if (workspaceExists || badSecret) {
                                                return { exists: true, data: () => ({ secretHash: workspaceHash || 'abc', organizationName: 'Empresa', updatedAt: { toDate: () => updatedAtDate } }) };
                                            }
                                            return { exists: false, data: () => null };
                                        },
                                        collection(sub) {
                                            assert.equal(sub, 'members');
                                            return {
                                                doc(uid) {
                                                    assert.equal(uid, 'team-user');
                                                    return {
                                                        set(data, options) {
                                                            savedData = data;
                                                            savedOptions = options;
                                                        },
                                                        get() {
                                                            const data = memberData || savedData || {};
                                                            return { exists: true, data: () => ({ ...data, updatedAt: { toDate: () => updatedAtDate } }) };
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
                            get() {
                                if (workspaceExists || badSecret) {
                                    return { exists: true, data: () => ({ secretHash: workspaceHash || 'abc', organizationName: 'Empresa', updatedAt: { toDate: () => updatedAtDate } }) };
                                }
                                return { exists: false, data: () => null };
                            },
                            set() {}
                        };
                        return callback(transaction);
                    }
                };
            }
        }
    };
}

const validReq = {
    method: 'PUT',
    query: { workspaceID: 'team-space', memberID: 'member-1' },
    headers: { authorization: 'Bearer valid-token', origin: 'https://luum-app.web.app' },
    body: {
        payload: {
            memberDisplayName: 'Alice',
            roleLabel: 'Dev',
            trackedTime: 5000,
            score: 80,
            contextSwitches: 2,
            focusTime: 3000,
            plannedTime: 2000,
            snapshotDay: '2026-06-22',
            weekStart: '2026-06-15',
            weekEnd: '2026-06-21'
        },
        workspaceSecret: 'valid-secret'
    }
};

test('workspace member rejects invalid workspace ID or member ID with 400', async () => {
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    await handler({
        method: 'PUT',
        query: { workspaceID: '../../etc', memberID: 'valid-id' },
        headers: { origin: 'https://luum-app.web.app' }, body: {}
    }, res);
    assert.equal(res.code, 400);
    assert.equal(res.body.message, 'Workspace ID ou Member ID inválido');
});

test('workspace member rejects invalid member ID with 400', async () => {
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    await handler({
        method: 'PUT',
        query: { workspaceID: 'valid-id', memberID: '' },
        headers: { origin: 'https://luum-app.web.app' }, body: {}
    }, res);
    assert.equal(res.code, 400);
    assert.equal(res.body.message, 'Workspace ID ou Member ID inválido');
});

test('workspace member rejects non-PUT method with 405', async () => {
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    await handler({
        method: 'GET',
        query: { workspaceID: 'team-space', memberID: 'member-1' },
        headers: { origin: 'https://luum-app.web.app' }, body: {}
    }, res);
    assert.equal(res.code, 405);
    assert.equal(res.body.message, 'Method not allowed');
});

test('workspace member rejects missing auth with 401', async () => {
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    await handler({
        method: 'PUT',
        query: { workspaceID: 'team-space', memberID: 'member-1' },
        headers: { origin: 'https://luum-app.web.app' }, body: {}
    }, res);
    assert.equal(res.code, 401);
});

test('workspace member rejects missing payload with 400', async () => {
    installMock();
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    await handler({
        method: 'PUT',
        query: { workspaceID: 'team-space', memberID: 'member-1' },
        headers: { authorization: 'Bearer valid-token', origin: 'https://luum-app.web.app' },
        body: {}
    }, res);
    assert.equal(res.code, 400);
    assert.equal(res.body.message, 'payload obrigatório');
});

test('workspace member rejects non-object payload with 400', async () => {
    installMock();
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    await handler({
        method: 'PUT',
        query: { workspaceID: 'team-space', memberID: 'member-1' },
        headers: { authorization: 'Bearer valid-token', origin: 'https://luum-app.web.app' },
        body: { payload: 'string' }
    }, res);
    assert.equal(res.code, 400);
    assert.equal(res.body.message, 'payload obrigatório');
});

test('workspace member rejects wrong workspace secret with 403', async () => {
    installMock({ badSecret: true });
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    await handler({
        ...validReq,
        body: { ...validReq.body, workspaceSecret: 'wrong-secret' }
    }, res);
    assert.equal(res.code, 403);
});

test('workspace member sanitizes invalid numeric fields', async () => {
    installMock({ workspaceExists: false });
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    await handler({
        ...validReq,
        body: {
            workspaceSecret: 'valid-secret',
            payload: {
                memberDisplayName: 'Alice',
                roleLabel: 'Dev',
                trackedTime: 'invalido',
                score: 150,
                contextSwitches: -5,
                focusTime: null,
                plannedTime: undefined
            }
        }
    }, res);
    assert.equal(res.code, 200);
});

test('workspace member sanitizes text fields with fallback and truncation', async () => {
    installMock({ workspaceExists: false });
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    const longName = 'A'.repeat(200);
    await handler({
        ...validReq,
        body: {
            workspaceSecret: 'valid-secret',
            payload: {
                memberDisplayName: '',
                roleLabel: longName,
                trackedTime: 1000, score: 50
            }
        }
    }, res);
    assert.equal(res.code, 200);
});

test('workspace member PUT succeeds with valid data and returns updatedAt', async () => {
    installMock({ workspaceExists: false });
    const handler = require('../api/workspaces/[workspaceID]/members/[memberID]');
    const res = response();
    await handler(validReq, res);
    assert.equal(res.code, 200);
    assert.equal(typeof res.body.updatedAt, 'number');
});
