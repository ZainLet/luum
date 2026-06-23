const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const aiPath = require.resolve('../api/ai/[action]');

function response() {
    return {
        body: null, code: 200, headers: {}, setHeader(name, value) { this.headers[name] = value; },
        status(code) { this.code = code; return this; },
        json(body) { this.body = body; return this; },
        end() { return this; }
    };
}

function installMock(userEntitlements = {}) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[aiPath];

    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath, filename: firebaseAdminPath, loaded: true,
        exports: {
            admin: {
                auth() {
                    return {
                        async verifyIdToken(token) {
                            if (token === 'bad-token') throw new Error('invalid token');
                            return { uid: 'test-user', email: 'test@luum.app' };
                        }
                    };
                },
                firestore: { FieldValue: { serverTimestamp() { return {}; } } }
            },
            getFirestore() {
                return {
                    collection() {
                        return {
                            doc() {
                                return {
                                    async get() {
                                        return {
                                            exists: true,
                                            data: () => ({
                                                plan: userEntitlements.plan || 'profissional',
                                                subscription: userEntitlements.subscription || { status: 'active', currentPeriodEnd: Date.now() + 86400000 }
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

const validBody = {
    kind: 'application',
    label: 'Visual Studio Code',
    secondaryLabel: 'code editor',
    currentCategoryID: 'work',
    categories: [
        { id: 'work', title: 'Trabalho' },
        { id: 'entertainment', title: 'Entretenimento' }
    ]
};

test('classify rejects missing auth header with 401', async () => {
    installMock();
    const handler = require('../api/ai/[action]');
    const res = response();
    await handler({
        method: 'POST', query: { action: 'classify' },
        headers: {}, body: validBody
    }, res);
    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Login Firebase obrigatório');
});

test('classify rejects invalid token with 401', async () => {
    installMock();
    const handler = require('../api/ai/[action]');
    const res = response();
    await handler({
        method: 'POST', query: { action: 'classify' },
        headers: { authorization: 'Bearer bad-token' }, body: validBody
    }, res);
    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Token Firebase inválido ou expirado');
});

test('classify rejects missing label with 400', async () => {
    installMock();
    const handler = require('../api/ai/[action]');
    const res = response();
    await handler({
        method: 'POST', query: { action: 'classify' },
        headers: { authorization: 'Bearer valid-token' },
        body: { kind: 'application', label: '' }
    }, res);
    assert.equal(res.code, 400);
    assert.equal(res.body.error, 'label obrigatório');
});

test('classify returns category and confidence when Gemini succeeds', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async (url, options) => {
        assert.ok(url.includes('generateContent'));
        return {
            ok: true,
            text: async () => JSON.stringify({
                candidates: [{ content: { parts: [{ text: '{"categoryID":"work","confidence":0.87,"reason":"Editor de código"}' }] } }]
            })
        };
    };
    try {
        installMock();
        process.env.GEMINI_API_KEY = 'test-key';
        const handler = require('../api/ai/[action]');
        const res = response();
        await handler({
            method: 'POST', query: { action: 'classify' },
            headers: { authorization: 'Bearer valid-token' }, body: validBody
        }, res);
        assert.equal(res.code, 200);
        assert.equal(res.body.categoryID, 'work');
        assert.equal(res.body.confidence, 0.87);
        assert.ok(res.body.reason);
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test('classify returns 502 when Gemini errors', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => ({ ok: false, status: 400, text: async () => 'Bad Request' });
    try {
        installMock();
        process.env.GEMINI_API_KEY = 'test-key';
        const handler = require('../api/ai/[action]');
        const res = response();
        await handler({
            method: 'POST', query: { action: 'classify' },
            headers: { authorization: 'Bearer valid-token' }, body: validBody
        }, res);
        assert.equal(res.code, 502);
        assert.ok(res.body.error);
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test('classify includes no-store cache control', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => {
        return {
            ok: true,
            text: async () => JSON.stringify({
                candidates: [{ content: { parts: [{ text: '{"categoryID":"work","confidence":0.9,"reason":"Produtivo"}' }] } }]
            })
        };
    };
    try {
        installMock();
        process.env.GEMINI_API_KEY = 'test-key';
        const handler = require('../api/ai/[action]');
        const res = response();
        await handler({
            method: 'POST', query: { action: 'classify' },
            headers: { authorization: 'Bearer valid-token' }, body: validBody
        }, res);
        assert.equal(res.body.categoryID, 'work');
    } finally {
        globalThis.fetch = originalFetch;
    }
});
