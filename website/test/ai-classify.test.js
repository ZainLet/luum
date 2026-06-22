const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const classifyPath = require.resolve('../api/ai/[action]');

function response() {
    return {
        body: null,
        code: 200,
        ended: false,
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
            this.ended = true;
            return this;
        }
    };
}

function installFirebaseAdminMock({ decoded, userExists = true, userData = {} }) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[classifyPath];

    const admin = {
        auth() {
            return {
                async verifyIdToken(token) {
                    assert.equal(token, 'valid-token');
                    return decoded;
                }
            };
        }
    };

    require.cache[firebaseAdminPath] = {
        id: firebaseAdminPath,
        filename: firebaseAdminPath,
        loaded: true,
        exports: {
            admin,
            getFirestore() {
                return {
                    collection(name) {
                        assert.equal(name, 'users');
                        return {
                            doc(uid) {
                                assert.equal(uid, decoded.uid);
                                return {
                                    async get() {
                                        return { exists: userExists, data: () => userData };
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

function classifyRequest(body = {}) {
    return {
        method: 'POST',
        query: { action: 'classify' },
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            kind: 'application',
            label: 'Figma',
            secondaryLabel: 'com.figma.Desktop',
            categories: [
                { id: 'work', title: 'Trabalho' },
                { id: 'entertainment', title: 'Entretenimento' },
                { id: 'communication', title: 'Comunicacao' },
                { id: 'learning', title: 'Aprendizado' },
                { id: 'utilities', title: 'Utilitarios' },
                { id: 'uncategorized', title: 'Sem categoria' }
            ],
            ...body
        }
    };
}

test('ai classify requires Firebase auth', async () => {
    installFirebaseAdminMock({
        decoded: { uid: 'user-1' },
        userData: { plan: 'profissional', subscription: { status: 'trial', trialEndsAt: { toMillis: () => Date.now() + 86_400_000 } } }
    });

    const handler = require('../api/ai/[action]');
    const res = response();
    await handler({ method: 'POST', query: { action: 'classify' }, headers: {}, body: {} }, res);

    assert.equal(res.code, 401);
});

test('ai classify fails clearly when Gemini key is missing', async () => {
    const oldKey = process.env.GEMINI_API_KEY;
    delete process.env.GEMINI_API_KEY;

    installFirebaseAdminMock({
        decoded: { uid: 'user-1' },
        userData: {
            plan: 'essencial',
            subscription: { status: 'trial', trialEndsAt: { toMillis: () => Date.now() + 86_400_000 } }
        }
    });

    const handler = require('../api/ai/[action]');
    const res = response();
    await handler(classifyRequest(), res);

    assert.equal(res.code, 503);
    assert.match(res.body.error, /GEMINI_API_KEY/);

    if (oldKey) process.env.GEMINI_API_KEY = oldKey;
});

test('ai query fails clearly when Gemini key is missing', async () => {
    const oldKey = process.env.GEMINI_API_KEY;
    delete process.env.GEMINI_API_KEY;

    installFirebaseAdminMock({
        decoded: { uid: 'user-1' },
        userData: {
            plan: 'essencial',
            subscription: { status: 'trial', trialEndsAt: { toMillis: () => Date.now() + 86_400_000 } }
        }
    });

    const handler = require('../api/ai/[action]');
    const res = response();
    await handler({
        method: 'POST',
        query: { action: 'query' },
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: {
            query: 'How was my week?',
            context: {
                date: '2026-06-22',
                totalTrackedTime: 18000,
                categoryBreakdown: [{ label: 'Trabalho', duration: 12000 }],
                topApps: [{ label: 'Xcode', duration: 7200 }]
            }
        }
    }, res);

    assert.equal(res.code, 503);
    assert.match(res.body.error, /GEMINI_API_KEY/);

    if (oldKey) process.env.GEMINI_API_KEY = oldKey;
});

test('ai classify proxies a valid Gemini JSON response', async () => {
    const oldKey = process.env.GEMINI_API_KEY;
    const oldFetch = global.fetch;
    process.env.GEMINI_API_KEY = 'test-gemini-key';

    installFirebaseAdminMock({
        decoded: { uid: 'user-1' },
        userData: {
            plan: 'profissional',
            subscription: { status: 'active', currentPeriodEnd: { toMillis: () => Date.now() + 86_400_000 } }
        }
    });

    global.fetch = async (url, options) => {
        assert.match(url, /generativelanguage\.googleapis\.com\/v1beta\/models\/gemini-2\.5-flash:generateContent$/);
        assert.equal(options.headers['x-goog-api-key'], 'test-gemini-key');
        assert.match(options.body, /Figma/);

        return {
            ok: true,
            status: 200,
            async text() {
                return JSON.stringify({
                    candidates: [{
                        content: {
                            parts: [{
                                text: '{"categoryID":"work","confidence":0.91,"reason":"Ferramenta de design/produtividade."}'
                            }]
                        }
                    }]
                });
            }
        };
    };

    const handler = require('../api/ai/[action]');
    const res = response();
    await handler(classifyRequest(), res);

    assert.equal(res.code, 200);
    assert.deepEqual(res.body, {
        categoryID: 'work',
        confidence: 0.91,
        reason: 'Ferramenta de design/produtividade.'
    });

    global.fetch = oldFetch;
    if (oldKey) {
        process.env.GEMINI_API_KEY = oldKey;
    } else {
        delete process.env.GEMINI_API_KEY;
    }
});

test('ai classify rejects invalid target payloads before Gemini call', async () => {
    const oldKey = process.env.GEMINI_API_KEY;
    process.env.GEMINI_API_KEY = 'test-gemini-key';

    installFirebaseAdminMock({
        decoded: { uid: 'user-1' },
        userData: {
            plan: 'essencial',
            subscription: { status: 'trial', trialEndsAt: { toMillis: () => Date.now() + 86_400_000 } }
        }
    });

    const handler = require('../api/ai/[action]');
    const res = response();
    await handler(classifyRequest({ kind: 'other' }), res);

    assert.equal(res.code, 400);

    if (oldKey) {
        process.env.GEMINI_API_KEY = oldKey;
    } else {
        delete process.env.GEMINI_API_KEY;
    }
});

test('ai classify rejects malformed JSON as a client error', async () => {
    installFirebaseAdminMock({
        decoded: { uid: 'user-1' },
        userData: {
            plan: 'profissional',
            subscription: { status: 'active', currentPeriodEnd: { toMillis: () => Date.now() + 86_400_000 } }
        }
    });

    const handler = require('../api/ai/[action]');
    const res = response();
    await handler({
        method: 'POST',
        query: { action: 'classify' },
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: '{"kind":'
    }, res);

    assert.equal(res.code, 400);
    assert.equal(res.body.error, 'JSON da classificação inválido');
});
