const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');

function response() {
    return {
        body: null, code: 200, headers: {},
        setHeader(name, value) { this.headers[name] = value; },
        status(code) { this.code = code; return this; },
        json(body) { this.body = body; return this; },
        end() { return this; }
    };
}

const sharedStore = {};

function installFirebaseMock(userData = {}) {
    delete require.cache[firebaseAdminPath];
    Object.keys(sharedStore).forEach(k => delete sharedStore[k]);

    function makeDoc(doc) {
        return {
            async get() {
                const exists = doc._data !== null;
                return { exists, data: () => exists ? doc._data : null };
            },
            set(data, opts) {
                doc._data = { ...(doc._data || {}), ...data };
                return Promise.resolve();
            },
            collection(sub) {
                if (!doc._collections[sub]) doc._collections[sub] = {};
                return makeCollection(doc._collections[sub]);
            },
            add(data) {
                const id = 'auto-' + Date.now();
                doc._collections[id] = { _data: data, _collections: {} };
                return Promise.resolve({ id });
            }
        };
    }

    function makeCollection(store) {
        return {
            doc(id) {
                if (!store[id]) store[id] = { _data: null, _collections: {} };
                return makeDoc(store[id]);
            },
            where(field, op, value) {
                const entries = Object.entries(store);
                const match = entries.find(([, d]) => d._data && d._data[field] === value);
                const matched = match ? [{ id: match[0], ...match[1] }] : [];
                return {
                    limit() {
                        return {
                            async get() {
                                return { empty: matched.length === 0, docs: matched.map(m => ({ id: m.id, data: () => m._data })) }
                            }
                        };
                    }
                };
            }
        };
    }

    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath, filename: firebaseAdminPath, loaded: true,
        exports: {
            admin: {
                auth() {
                    return {
                        async verifyIdToken(token) {
                            if (token === 'bad-token') throw new Error('bad');
                            return { uid: 'test-user', email: 'test@luum.app' };
                        }
                    };
                },
                firestore: { FieldValue: { serverTimestamp() { return {}; } } }
            },
            getFirestore() {
                return {
                    collection(name) {
                        if (!sharedStore[name]) sharedStore[name] = {};
                        return makeCollection(sharedStore[name]);
                    }
                };
            }
        }
    };
}

function deleteHandlers() {
    const paths = [
        '../api/integrations/_notion-auth',
        '../api/integrations/_notion-callback',
        '../api/integrations/_notion-pages',
        '../api/integrations/_clickup-webhook',
        '../api/integrations/_linear-auth',
        '../api/integrations/_linear-issues',
        '../api/integrations/_zapier-trigger',
        '../api/integrations/_zapier-action',
        '../api/_integrationSettings',
        '../api/_entitlements'
    ];
    for (const p of paths) {
        try {
            const resolved = require.resolve(p);
            delete require.cache[resolved];
        } catch { /* module not yet loaded */ }
    }
}

test('notion-auth GET returns auth URL', async () => {
    installFirebaseMock({ plan: 'profissional' });
    deleteHandlers();
    process.env.NOTION_CLIENT_ID = 'notion-client-id';
    const handler = require('../api/integrations/_notion-auth');
    const res = response();
    await handler({
        method: 'GET', headers: { authorization: 'Bearer valid-token', host: 'localhost:3000' },
        body: {}, query: {}
    }, res);
    assert.equal(res.code, 200);
    assert.ok(res.body.url);
    assert.ok(res.body.url.includes('notion.com'));
});

test('notion-auth rejects non-GET method with 405', async () => {
    installFirebaseMock({ plan: 'profissional' });
    deleteHandlers();
    process.env.NOTION_CLIENT_ID = 'notion-client-id';
    const handler = require('../api/integrations/_notion-auth');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: {}, query: {}
    }, res);
    assert.equal(res.code, 405);
});

test('notion-auth rejects missing firebase token with 401', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_notion-auth');
    const res = response();
    await handler({ method: 'GET', headers: {}, body: {}, query: {} }, res);
    assert.equal(res.code, 401);
});

test('notion-auth returns 503 when NOTION_CLIENT_ID not configured', async () => {
    installFirebaseMock({ plan: 'profissional' });
    deleteHandlers();
    delete process.env.NOTION_CLIENT_ID;
    const handler = require('../api/integrations/_notion-auth');
    const res = response();
    await handler({
        method: 'GET', headers: { authorization: 'Bearer valid-token', host: 'localhost:3000' },
        body: {}, query: {}
    }, res);
    assert.equal(res.code, 503);
});

test('notion-pages rejects non-configured integration', async () => {
    installFirebaseMock({ plan: 'profissional' });
    deleteHandlers();
    const handler = require('../api/integrations/_notion-pages');
    const res = response();
    await handler({
        method: 'GET', headers: { authorization: 'Bearer valid-token' }, body: {}, query: {}
    }, res);
    assert.ok(res.code === 400 || res.code === 403);
    assert.ok(res.body.error);
});

test('linear-auth GET returns auth URL with correct callback redirect_uri', async () => {
    installFirebaseMock({ plan: 'profissional' });
    deleteHandlers();
    process.env.LINEAR_CLIENT_ID = 'linear-client';
    process.env.LINEAR_CLIENT_SECRET = 'linear-secret';
    const handler = require('../api/integrations/_linear-auth');
    const res = response();
    await handler({
        method: 'GET', headers: { authorization: 'Bearer valid-token', host: 'localhost:3000' },
        body: {}
    }, res);
    assert.equal(res.code, 200);
    assert.ok(res.body.url);
    assert.ok(res.body.url.includes('linear.app'));
    assert.ok(res.body.url.includes('linear-callback'), 'redirect_uri deve apontar para linear-callback');
});

test('linear-auth rejects non-GET method', async () => {
    installFirebaseMock();
    deleteHandlers();
    process.env.LINEAR_CLIENT_ID = 'linear-client';
    const handler = require('../api/integrations/_linear-auth');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: {}
    }, res);
    assert.equal(res.code, 405);
});

test('linear-issues rejects unauthenticated Linear', async () => {
    installFirebaseMock({ plan: 'profissional' });
    deleteHandlers();
    const handler = require('../api/integrations/_linear-issues');
    const res = response();
    await handler({
        method: 'GET', headers: { authorization: 'Bearer valid-token' }, body: {}
    }, res);
    assert.ok(res.code === 400 || res.code === 403);
});

test('clickup-webhook rejects missing secret with 503', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_clickup-webhook');
    const res = response();
    await handler({
        method: 'POST', headers: {}, body: { event: 'taskCreated' }
    }, res);
    assert.equal(res.code, 503);
});

test('zapier-trigger requires auth', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-trigger');
    const res = response();
    await handler({
        method: 'POST', headers: {}, body: {}
    }, res);
    assert.equal(res.code, 401);
});

test('zapier-action rejects unknown token', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-action');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer unknown-token' },
        body: { action: 'test', payload: {} }
    }, res);
    assert.equal(res.code, 403);
    assert.ok(res.body.error);
});
