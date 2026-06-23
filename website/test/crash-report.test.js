const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const corsPath = require.resolve('../api/_cors');
const headersPath = require.resolve('../api/_httpHeaders');
const jsonBodyPath = require.resolve('../api/_jsonBody');
const crashReportPath = require.resolve('../api/crash-report');

function response() {
    return {
        body: null, code: 200, headers: {},
        setHeader(name, value) { this.headers[name] = value; },
        status(code) { this.code = code; return this; },
        json(body) { this.body = body; return this; },
        end() { return this; }
    };
}

function installMocks() {
    for (const p of [firebaseAdminPath, corsPath, headersPath, jsonBodyPath, crashReportPath]) {
        delete require.cache[p];
    }

    require.cache[corsPath] = {
        id: corsPath, filename: corsPath, loaded: true,
        exports: {
            applyCorsHeaders(req, res) { return false; },
            addCors() {}
        }
    };

    require.cache[headersPath] = {
        id: headersPath, filename: headersPath, loaded: true,
        exports: {
            applySecurityHeaders() {},
            addNoStoreHeaders() {}
        }
    };

    require.cache[jsonBodyPath] = {
        id: jsonBodyPath, filename: jsonBodyPath, loaded: true,
        exports: {
            parseJsonBody(req) { return req.body || {}; },
            jsonBody(req) { return req.body || {}; }
        }
    };

    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath, filename: firebaseAdminPath, loaded: true,
        exports: {
            admin: {
                auth() {
                    return {
                        async verifyIdToken(token) {
                            if (token === 'bad-token') throw new Error('invalid token');
                            return { uid: 'crash-user', email: 'user@luum.app' };
                        }
                    };
                },
                firestore: { FieldValue: { serverTimestamp() { return {}; } } }
            },
            getFirestore() {
                const stores = {};
                function ensureCollection(name) {
                    if (!stores[name]) stores[name] = {};
                    return {
                        doc(id) {
                            if (!stores[name][id]) stores[name][id] = { _data: null, _sub: {} };
                            const d = stores[name][id];
                            return {
                                set(data) { d._data = data; return Promise.resolve(); },
                                update(data) { Object.assign(d._data || {}, data); return Promise.resolve(); },
                                get() { return Promise.resolve({ exists: d._data !== null, data: () => d._data }); },
                                collection(sub) {
                                    if (!d._sub[sub]) d._sub[sub] = {};
                                    return {
                                        doc(sid) {
                                            if (!d._sub[sub][sid]) d._sub[sub][sid] = {};
                                            const sd = d._sub[sub][sid];
                                            return {
                                                set(data) { Object.assign(sd, data); return Promise.resolve(); },
                                                update(data) { Object.assign(sd, data); return Promise.resolve(); },
                                                get() { return Promise.resolve({ exists: true, data: () => sd }); }
                                            };
                                        },
                                        orderBy() { return this; },
                                        where() { return this; },
                                        limit(n) {
                                            return {
                                                get() {
                                                    const entries = Object.entries(d._sub[sub] || {});
                                                    const docs = entries.map(([id, data]) => ({ id, data: () => data }));
                                                    return Promise.resolve({ empty: docs.length === 0, forEach(fn) { docs.forEach(fn); }, docs });
                                                }
                                            };
                                        },
                                        listDocuments() {
                                            return Promise.resolve(Object.keys(d._sub[sub] || {}).map(id => ({ id })));
                                        }
                                    };
                                }
                            };
                        }
                    };
                }
                return { collection: ensureCollection };
            }
        }
    };
}

const validCrashBody = {
    appVersion: '0.0.2',
    build: '42',
    macOSVersion: '15.2',
    errorType: 'NSInternalInconsistencyException',
    exceptionName: 'NSInvalidArgumentException',
    stack: '0   CoreFoundation 0x1234 …',
    message: 'Erro ao acessar sharedFileList'
};

test('crash-report rejects missing token with 401', async () => {
    installMocks();
    const handler = require('../api/crash-report');
    const res = response();
    await handler({ method: 'POST', headers: {}, body: validCrashBody }, res);
    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Login necessário.');
});

test('crash-report rejects invalid token with 401', async () => {
    installMocks();
    const handler = require('../api/crash-report');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer bad-token' }, body: validCrashBody
    }, res);
    assert.equal(res.code, 401);
});

test('crash-report rejects missing appVersion with 400', async () => {
    installMocks();
    const handler = require('../api/crash-report');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: { errorType: 'crash' }
    }, res);
    assert.equal(res.code, 400);
    assert.ok(res.body.error);
});

test('crash-report rejects missing errorType with 400', async () => {
    installMocks();
    const handler = require('../api/crash-report');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: { appVersion: '0.0.2' }
    }, res);
    assert.equal(res.code, 400);
});

test('crash-report accepts valid payload and returns reportId', async () => {
    installMocks();
    const handler = require('../api/crash-report');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' }, body: validCrashBody
    }, res);
    assert.equal(res.code, 200);
    assert.equal(res.body.ok, true);
    assert.ok(res.body.reportId);
});

test('crash-report sanitizes long base64 stack', async () => {
    installMocks();
    const handler = require('../api/crash-report');
    const res = response();
    const longBase64 = 'A'.repeat(50) + 'B'.repeat(50);
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: { ...validCrashBody, stack: 'prefix ' + longBase64 + ' suffix' }
    }, res);
    assert.equal(res.code, 200);
});

test('crash-report rejects non-POST method with 405', async () => {
    installMocks();
    const handler = require('../api/crash-report');
    const res = response();
    await handler({ method: 'GET', headers: {}, body: {} }, res);
    assert.equal(res.code, 405);
});

const adminActionsPath = require.resolve('../api/_adminActions');
const adminAuthPath = require.resolve('../api/_adminAuth');
const adminClaimsPath = require.resolve('../api/_adminClaims');
const entitlementsPath = require.resolve('../api/_entitlements');
const adminGrantInputPath = require.resolve('../api/_adminGrantInput');
const stripePath = require.resolve('../api/_stripe');
const integrationSettingsPath = require.resolve('../api/_integrationSettings');
const manualGrantPath = require.resolve('../api/_manualGrant');
const publicConfigPath = require.resolve('../api/_publicConfig');

function installAdminMocks() {
    for (const p of [firebaseAdminPath, corsPath, headersPath, jsonBodyPath,
        adminActionsPath, adminAuthPath, adminClaimsPath, entitlementsPath,
        adminGrantInputPath, stripePath, integrationSettingsPath,
        manualGrantPath, publicConfigPath]) {
        delete require.cache[p];
    }

    require.cache[corsPath] = {
        id: corsPath, filename: corsPath, loaded: true,
        exports: { applyCorsHeaders() { return false; }, addCors() {}, handleOptions() {} }
    };
    require.cache[headersPath] = {
        id: headersPath, filename: headersPath, loaded: true,
        exports: { applySecurityHeaders() {}, addNoStoreHeaders() {} }
    };
    require.cache[jsonBodyPath] = {
        id: jsonBodyPath, filename: jsonBodyPath, loaded: true,
        exports: { parseJsonBody(req) { return req.body || {}; }, jsonBody(req) { return req.body || {}; } }
    };

    const crashUid = 'crash-user';
    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath, filename: firebaseAdminPath, loaded: true,
        exports: {
            admin: {
                auth() {
                    return {
                        async verifyIdToken(token) {
                            if (token === 'bad-token') throw new Error('invalid token');
                            if (token === 'non-admin-token') return { uid: 'normal-user', email: 'user@test.com' };
                            return { uid: 'admin-user', email: 'oluum.app@gmail.com', luumAdmin: true };
                        }
                    };
                },
                firestore: { FieldValue: { serverTimestamp() { return {}; }, delete() { return {}; } } }
            },
            getAdminApp() {},
            getFirestore() {
                const data = {};
                const refs = {
                    collection(name) {
                        if (!data[name]) data[name] = {};
                        return {
                            doc(id) {
                                if (!data[name][id]) data[name][id] = { _sub: {} };
                                const d = data[name][id];
                                return {
                                    set(...args) { d._data = args[0]; return Promise.resolve(); },
                                    update(...args) { Object.assign(d._data || {}, args[0]); return Promise.resolve(); },
                                    get() { return Promise.resolve({ exists: d._data !== null, data: () => d._data }); },
                                    collection(sub) {
                                        if (!d._sub[sub]) d._sub[sub] = { _entries: {} };
                                        const c = d._sub[sub];
                                        return {
                                            doc(sid) {
                                                if (!c._entries[sid]) c._entries[sid] = {};
                                                const sd = c._entries[sid];
                                                return {
                                                    set(data) { Object.assign(sd, data); return Promise.resolve(); },
                                                    update(data) { Object.assign(sd, data); return Promise.resolve(); },
                                                    get() { return Promise.resolve({ exists: true, data: () => sd }); }
                                                };
                                            },
                                            orderBy() { return this; },
                                            where() { return this; },
                                            limit(n) {
                                                return {
                                                    get() {
                                                        const docs = Object.entries(c._entries).map(([id, data]) => ({
                                                            id, data: () => data
                                                        }));
                                                        return Promise.resolve({ empty: docs.length === 0, forEach(fn) { docs.forEach(fn); }, docs });
                                                    }
                                                };
                                            },
                                            get() {
                                                const docs = Object.entries(c._entries).map(([id, data]) => ({
                                                    id, data: () => data
                                                }));
                                                return Promise.resolve({ empty: docs.length === 0, forEach(fn) { docs.forEach(fn); }, docs });
                                            },
                                            listDocuments() {
                                                return Promise.resolve(Object.keys(c._entries).map(id => ({ id })));
                                            }
                                        };
                                    }
                                };
                            },
                            listDocuments() {
                                const entries = data[name];
                                return Promise.resolve(Object.keys(entries).map(id => ({
                                    id,
                                    collection(sub) {
                                        if (!entries[id]) entries[id] = { _sub: {} };
                                        if (!entries[id]._sub[sub]) entries[id]._sub[sub] = { _entries: {} };
                                        const c = entries[id]._sub[sub];
                                        return {
                                            doc(sid) {
                                                if (!c._entries[sid]) c._entries[sid] = {};
                                                return {
                                                    set(data) { Object.assign(c._entries[sid], data); return Promise.resolve(); },
                                                    update(data) { Object.assign(c._entries[sid], data); return Promise.resolve(); },
                                                    get() { return Promise.resolve({ exists: true }); }
                                                };
                                            },
                                            orderBy() { return this; },
                                            where() { return this; },
                                            limit(n) {
                                                return {
                                                    get() {
                                                        const docs = Object.entries(c._entries).map(([id, data]) => ({
                                                            id, data: () => data
                                                        }));
                                                        return Promise.resolve({ empty: docs.length === 0, forEach(fn) { docs.forEach(fn); }, docs });
                                                    }
                                                };
                                            },
                                            get() {
                                                const docs = Object.entries(c._entries).map(([id, data]) => ({
                                                    id, data: () => data
                                                }));
                                                return Promise.resolve({ empty: docs.length === 0, forEach(fn) { docs.forEach(fn); }, docs });
                                            }
                                        };
                                    }
                                })));
                            }
                        };
                    }
                };
                return refs;
            }
        }
    };

    require.cache[adminAuthPath] = {
        id: adminAuthPath, filename: adminAuthPath, loaded: true,
        exports: {
            allowedAdminEmails() { return ['oluum.app@gmail.com']; },
            async requireAdmin(req, res) {
                const ah = req.headers.authorization || '';
                if (!ah.startsWith('Bearer ')) {
                    res.status(401).json({ error: 'Login Firebase obrigatório' });
                    return null;
                }
                const fb = require.cache[firebaseAdminPath].exports;
                try {
                    const decoded = await fb.admin.auth().verifyIdToken(ah.slice('Bearer '.length));
                    const email = (decoded.email || '').toLowerCase();
                    if (email === 'oluum.app@gmail.com' || decoded.luumAdmin || decoded.admin) {
                        return decoded;
                    }
                    res.status(403).json({ error: 'Usuário sem permissão de admin' });
                    return null;
                } catch {
                    res.status(401).json({ error: 'Token Firebase inválido ou expirado' });
                    return null;
                }
            }
        }
    };

    require.cache[adminClaimsPath] = {
        id: adminClaimsPath, filename: adminClaimsPath, loaded: true,
        exports: { claimsForAdminRole() { return {}; } }
    };
    require.cache[entitlementsPath] = {
        id: entitlementsPath, filename: entitlementsPath, loaded: true,
        exports: { accountPlan() { return 'essencial'; } }
    };
    require.cache[adminGrantInputPath] = {
        id: adminGrantInputPath, filename: adminGrantInputPath, loaded: true,
        exports: {
            normalizeAdminPlan(v) { return v || 'essencial'; },
            normalizeAdminRole(v) { return v || 'user'; },
            normalizeAdminStatus(v) { return v || 'active'; },
            normalizeSeats(v) { return String(v || '1'); }
        }
    };
    require.cache[stripePath] = {
        id: stripePath, filename: stripePath, loaded: true,
        exports: {
            async getStripe() { return { webhookEndpoints: { async create() { return { secret: 'whsec_test' }; } } }; },
            minimumQuantity() { return 1; },
            missingStripeEnvNames() { return []; }
        }
    };
    require.cache[integrationSettingsPath] = {
        id: integrationSettingsPath, filename: integrationSettingsPath, loaded: true,
        exports: {
            async getSetting() { return null; },
            async maskedSettings() { return {}; },
            async saveSettings() {},
            SETTINGS: {}
        }
    };
    require.cache[manualGrantPath] = {
        id: manualGrantPath, filename: manualGrantPath, loaded: true,
        exports: {
            manualSubscriptionSnapshot() { return { status: 'active' }; },
            stripeSubscriptionDeletePatch() { return {}; }
        }
    };
    require.cache[publicConfigPath] = {
        id: publicConfigPath, filename: publicConfigPath, loaded: true,
        exports: { PUBLIC_SITE_URL: 'https://luum.app', webhookURL() { return 'https://luum.app/api/webhook'; } }
    };
}

test('admin crash-reports GET rejects without token (401)', async () => {
    installAdminMocks();
    const { crashReportsHandler } = require('../api/_adminActions');
    const res = response();
    await crashReportsHandler({ method: 'GET', query: {}, headers: {}, body: {} }, res);
    assert.equal(res.code, 401);
});

test('admin crash-reports GET rejects invalid token (401)', async () => {
    installAdminMocks();
    const { crashReportsHandler } = require('../api/_adminActions');
    const res = response();
    await crashReportsHandler({
        method: 'GET', query: {}, headers: { authorization: 'Bearer bad-token' }, body: {}
    }, res);
    assert.equal(res.code, 401);
});

test('admin crash-reports GET rejects non-admin token (403)', async () => {
    installAdminMocks();
    const { crashReportsHandler } = require('../api/_adminActions');
    const res = response();
    await crashReportsHandler({
        method: 'GET', query: {}, headers: { authorization: 'Bearer non-admin-token' }, body: {}
    }, res);
    assert.equal(res.code, 403);
});

test('admin crash-reports GET returns empty list (200)', async () => {
    installAdminMocks();
    const { crashReportsHandler } = require('../api/_adminActions');
    const res = response();
    await crashReportsHandler({
        method: 'GET', query: {}, headers: { authorization: 'Bearer admin-token' }, body: {}
    }, res);
    assert.equal(res.code, 200);
    assert.equal(res.body.ok, true);
    assert.deepEqual(res.body.reports, []);
});

test('admin crash-reports PATCH requires uid (400)', async () => {
    installAdminMocks();
    const { crashReportsHandler } = require('../api/_adminActions');
    const res = response();
    await crashReportsHandler({
        method: 'PATCH', headers: { authorization: 'Bearer admin-token' },
        body: { reportId: 'r1', status: 'resolvido' }
    }, res);
    assert.equal(res.code, 400);
});

test('admin crash-reports PATCH rejects invalid status (400)', async () => {
    installAdminMocks();
    const { crashReportsHandler } = require('../api/_adminActions');
    const res = response();
    await crashReportsHandler({
        method: 'PATCH', headers: { authorization: 'Bearer admin-token' },
        body: { uid: 'u1', reportId: 'r1', status: 'invalid-status' }
    }, res);
    assert.equal(res.code, 400);
});

test('admin crash-reports PATCH accepts valid update (200)', async () => {
    installAdminMocks();
    const { crashReportsHandler } = require('../api/_adminActions');
    const res = response();
    await crashReportsHandler({
        method: 'PATCH', headers: { authorization: 'Bearer admin-token' },
        body: { uid: 'u1', reportId: 'r1', status: 'resolvido' }
    }, res);
    assert.equal(res.code, 200);
    assert.equal(res.body.ok, true);
});
