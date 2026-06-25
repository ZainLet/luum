const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');

function response() {
    return {
        body: null, code: 200, headers: {},
        redirectUrl: null,
        setHeader(name, value) { this.headers[name] = value; },
        status(code) { this.code = code; return this; },
        json(body) { this.body = body; return this; },
        redirect(url) { this.redirectUrl = url; return this; },
        end() { return this; }
    };
}

function makeState(secret, stateVal) {
    const hmac = crypto.createHmac('sha256', secret).update(stateVal).digest('hex');
    return `${stateVal}.${hmac}`;
}

function mockFetch(responseBody, ok = true, status = 200) {
    global.fetch = async () => ({
        ok,
        status,
        json: async () => responseBody,
    });
}

function restoreFetch() {
    delete global.fetch;
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
            delete() {
                doc._data = null;
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
        '../api/integrations/_clickup-auth',
        '../api/integrations/_clickup-callback',
        '../api/integrations/_zapier-webhook-config',
        '../api/integrations/_linear-auth',
        '../api/integrations/_linear-callback',
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
    assert.ok(res.body.url.includes('state='), 'URL deve incluir parâmetro state para CSRF protection');
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
    assert.ok(res.body.error, 'deve retornar corpo com campo error');
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

test('linear-callback rejeita state com HMAC inválido', async () => {
    deleteHandlers();
    process.env.LINEAR_CLIENT_SECRET = 'linear-secret';
    const handler = require('../api/integrations/_linear-callback');
    const res = response();
    await handler({
        method: 'GET', headers: { host: 'localhost:3000' },
        query: { code: 'abc123', state: 'validval.badhmacinvalid0000000000000000000000000000000000000000000000' }
    }, res);
    assert.ok(res.redirectUrl, 'deve redirecionar');
    assert.ok(res.redirectUrl.includes('error=invalid_state'), `esperado invalid_state, recebido: ${res.redirectUrl}`);
    restoreFetch();
});

test('linear-callback rejeita ausência de state quando secret configurado', async () => {
    deleteHandlers();
    process.env.LINEAR_CLIENT_SECRET = 'linear-secret';
    const handler = require('../api/integrations/_linear-callback');
    const res = response();
    await handler({
        method: 'GET', headers: { host: 'localhost:3000' },
        query: { code: 'abc123' }
    }, res);
    assert.ok(res.redirectUrl);
    assert.ok(res.redirectUrl.includes('error=missing_state'), `esperado missing_state, recebido: ${res.redirectUrl}`);
    restoreFetch();
});

test('linear-callback troca código por token com sucesso', async () => {
    deleteHandlers();
    process.env.LINEAR_CLIENT_ID = 'linear-client';
    process.env.LINEAR_CLIENT_SECRET = 'linear-secret';
    mockFetch({ access_token: 'tok123', token_type: 'Bearer', scope: 'read' });
    const handler = require('../api/integrations/_linear-callback');
    const res = response();
    const state = makeState('linear-secret', 'randomval123');
    await handler({
        method: 'GET', headers: { host: 'localhost:3000' },
        query: { code: 'auth-code', state }
    }, res);
    assert.ok(res.redirectUrl, 'deve redirecionar para luum://');
    assert.ok(res.redirectUrl.startsWith('luum://linear?'), `esperado luum://linear, recebido: ${res.redirectUrl}`);
    assert.ok(res.redirectUrl.includes('access_token=tok123'), `deve incluir access_token`);
    restoreFetch();
});

test('linear-callback redireciona com erro quando troca de código falha', async () => {
    deleteHandlers();
    process.env.LINEAR_CLIENT_ID = 'linear-client';
    process.env.LINEAR_CLIENT_SECRET = 'linear-secret';
    mockFetch({ error: 'invalid_grant' }, false, 400);
    const handler = require('../api/integrations/_linear-callback');
    const res = response();
    const state = makeState('linear-secret', 'randomval456');
    await handler({
        method: 'GET', headers: { host: 'localhost:3000' },
        query: { code: 'bad-code', state }
    }, res);
    assert.ok(res.redirectUrl);
    assert.ok(res.redirectUrl.includes('error='), `esperado error na URL, recebido: ${res.redirectUrl}`);
    restoreFetch();
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

test('zapier-action rejects bad token', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-action');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer bad-token' },
        body: { summary: 'test', date: '2026-06-25', totalMinutes: 60 }
    }, res);
    assert.equal(res.code, 403);
    assert.ok(res.body.error);
});

test('zapier-action returns 404 when webhook not configured', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-action');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: { summary: 'Resumo do dia', date: '2026-06-25', totalMinutes: 120 }
    }, res);
    assert.equal(res.code, 404);
    assert.ok(res.body.error);
});

// --- clickup-auth ---

test('clickup-auth GET retorna URL de autorização', async () => {
    installFirebaseMock({ plan: 'profissional' });
    deleteHandlers();
    process.env.CLICKUP_CLIENT_ID = 'clickup-client';
    const handler = require('../api/integrations/_clickup-auth');
    const res = response();
    await handler({
        method: 'GET', headers: { authorization: 'Bearer valid-token', host: 'localhost:3000' },
        body: {}
    }, res);
    assert.equal(res.code, 200);
    assert.ok(res.body.url);
    assert.ok(res.body.url.includes('app.clickup.com'), `esperado clickup.com, recebido: ${res.body.url}`);
    assert.ok(res.body.url.includes('clickup-callback'), 'redirect_uri deve incluir clickup-callback');
});

test('clickup-auth rejeita método não-GET com 405', async () => {
    installFirebaseMock({ plan: 'profissional' });
    deleteHandlers();
    process.env.CLICKUP_CLIENT_ID = 'clickup-client';
    const handler = require('../api/integrations/_clickup-auth');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' }, body: {}
    }, res);
    assert.equal(res.code, 405);
    assert.ok(res.body.error);
});

test('clickup-auth retorna 503 quando CLICKUP_CLIENT_ID não configurado', async () => {
    installFirebaseMock({ plan: 'profissional' });
    deleteHandlers();
    delete process.env.CLICKUP_CLIENT_ID;
    const handler = require('../api/integrations/_clickup-auth');
    const res = response();
    await handler({
        method: 'GET', headers: { authorization: 'Bearer valid-token', host: 'localhost:3000' },
        body: {}
    }, res);
    assert.equal(res.code, 503);
    assert.ok(res.body.error);
});

// --- clickup-callback ---

test('clickup-callback redireciona para luum://clickup em sucesso', async () => {
    deleteHandlers();
    process.env.CLICKUP_CLIENT_ID = 'clickup-client';
    process.env.CLICKUP_CLIENT_SECRET = 'clickup-secret';
    mockFetch({ access_token: 'cu_tok123' });
    const handler = require('../api/integrations/_clickup-callback');
    const res = response();
    await handler({
        method: 'GET', headers: { host: 'localhost:3000' },
        query: { code: 'auth-code' }
    }, res);
    assert.ok(res.redirectUrl, 'deve redirecionar');
    assert.ok(res.redirectUrl.startsWith('luum://clickup?'), `esperado luum://clickup, recebido: ${res.redirectUrl}`);
    assert.ok(res.redirectUrl.includes('access_token=cu_tok123'));
    restoreFetch();
});

test('clickup-callback redireciona com erro quando troca falha', async () => {
    deleteHandlers();
    process.env.CLICKUP_CLIENT_ID = 'clickup-client';
    process.env.CLICKUP_CLIENT_SECRET = 'clickup-secret';
    mockFetch({ error: 'invalid_code' }, false);
    const handler = require('../api/integrations/_clickup-callback');
    const res = response();
    await handler({
        method: 'GET', headers: { host: 'localhost:3000' },
        query: { code: 'bad-code' }
    }, res);
    assert.ok(res.redirectUrl);
    assert.ok(res.redirectUrl.includes('error='), `esperado error na URL, recebido: ${res.redirectUrl}`);
    restoreFetch();
});

// --- zapier-webhook-config ---

test('zapier-webhook-config GET retorna lista vazia quando não configurado', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-webhook-config');
    const res = response();
    await handler({
        method: 'GET', headers: { authorization: 'Bearer valid-token' }, body: {}
    }, res);
    assert.equal(res.code, 200);
    assert.deepEqual(res.body.webhooks, []);
});

test('zapier-webhook-config POST webhooks array válido', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-webhook-config');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: {
            webhooks: [
                { url: 'https://hooks.zapier.com/hooks/catch/123/abc', label: 'Foco', events: ['focus_mode'] },
                { url: 'https://hooks.zapier.com/hooks/catch/456/def', label: 'Calendário', events: ['calendar_sync'] },
            ]
        }
    }, res);
    assert.equal(res.code, 200);
    assert.ok(res.body.ok);
    assert.equal(res.body.webhooks.length, 2);
    assert.equal(res.body.webhooks[0].label, 'Foco');
    assert.equal(res.body.webhooks[1].events[0], 'calendar_sync');
});

test('zapier-webhook-config POST rejeita webhooks com URL inválida', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-webhook-config');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: {
            webhooks: [
                { url: 'https://evil.com/webhook', label: 'Bad' }
            ]
        }
    }, res);
    assert.equal(res.code, 400);
    assert.ok(res.body.error);
});

test('zapier-webhook-config POST webhooks vazio remove configuração', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-webhook-config');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: { webhooks: [] }
    }, res);
    assert.equal(res.code, 200);
    assert.ok(res.body.ok);
});

test('zapier-webhook-config backward compat: POST webhookUrl singular', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-webhook-config');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: { webhookUrl: 'https://hooks.zapier.com/hooks/catch/123/abc' }
    }, res);
    assert.equal(res.code, 200);
    assert.ok(res.body.ok);
    assert.equal(res.body.webhooks.length, 1);
    assert.equal(res.body.webhooks[0].url, 'https://hooks.zapier.com/hooks/catch/123/abc');
});

test('zapier-webhook-config backward compat: POST webhookUrl null remove', async () => {
    installFirebaseMock();
    deleteHandlers();
    const handler = require('../api/integrations/_zapier-webhook-config');
    const res = response();
    await handler({
        method: 'POST', headers: { authorization: 'Bearer valid-token' },
        body: { webhookUrl: null }
    }, res);
    assert.equal(res.code, 200);
    assert.ok(res.body.ok);
});

test('zapier-webhook-config GET retorna webhooks migrados do formato antigo', async () => {
    installFirebaseMock();
    deleteHandlers();
    sharedStore['zapier_webhooks'] = {
        'test-user': { _data: { webhookUrl: 'https://hooks.zapier.com/hooks/catch/old/format' }, _collections: {} }
    };
    const handler = require('../api/integrations/_zapier-webhook-config');
    const res = response();
    await handler({
        method: 'GET', headers: { authorization: 'Bearer valid-token' }, body: {}
    }, res);
    assert.equal(res.code, 200);
    assert.equal(res.body.webhooks.length, 1);
    assert.equal(res.body.webhooks[0].url, 'https://hooks.zapier.com/hooks/catch/old/format');
});
