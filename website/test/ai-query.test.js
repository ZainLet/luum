'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { resetAll } = require('../api/_rateLimit');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const aiPath = require.resolve('../api/ai/[action]');

function response() {
    return {
        body: null, code: 200, headers: {},
        setHeader(name, value) { this.headers[name] = value; },
        status(code) { this.code = code; return this; },
        json(body) { this.body = body; return this; },
        end() { return this; }
    };
}

function installMock(opts = {}) {
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
                            return { uid: opts.uid || 'query-user', email: 'query@luum.app' };
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
                                            exists: opts.userExists !== false,
                                            data: () => ({
                                                plan: opts.plan || 'profissional',
                                                subscription: { status: 'active', currentPeriodEnd: Date.now() + 86400000 }
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

function makeReq(overrides = {}) {
    return {
        method: 'POST',
        query: { action: 'query' },
        headers: { authorization: 'Bearer valid-token' },
        body: {
            query: 'Quanto tempo trabalhei hoje?',
            context: {
                date: '27 jun. 2026',
                totalTrackedTime: 7200,
                categoryBreakdown: [{ label: 'Trabalho', duration: 5000 }],
                topApps: [{ label: 'VS Code', duration: 3000 }]
            }
        },
        ...overrides
    };
}

function mockGeminiOk(answer = 'Você trabalhou 2 horas hoje.') {
    return async () => ({
        ok: true,
        text: async () => JSON.stringify({
            candidates: [{ content: { parts: [{ text: answer }] } }]
        })
    });
}

test('query rejeita sem Authorization header com 401', async () => {
    installMock();
    const handler = require('../api/ai/[action]');
    const res = response();
    await handler(makeReq({ headers: {} }), res);
    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Login Firebase obrigatório');
});

test('query rejeita token inválido com 401', async () => {
    installMock();
    const handler = require('../api/ai/[action]');
    const res = response();
    await handler(makeReq({ headers: { authorization: 'Bearer bad-token' } }), res);
    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Token Firebase inválido ou expirado');
});

test('query rejeita usuário sem conta Luum com 403', async () => {
    installMock({ userExists: false });
    const handler = require('../api/ai/[action]');
    const res = response();
    await handler(makeReq(), res);
    assert.equal(res.code, 403);
    assert.equal(res.body.error, 'Conta Luum não encontrada');
});

test('query rejeita usuário com plano bloqueado (trial expirado) com 403', async () => {
    // status 'trial' com trialEndsAt no passado → locked: true
    installMock({ plan: 'gratuito', trialExpired: true });
    delete require.cache[aiPath];
    const firebasePathRef = require.resolve('../api/_firebaseAdmin');
    delete require.cache[firebasePathRef];
    require.cache[firebasePathRef] = {
        id: firebasePathRef, filename: firebasePathRef, loaded: true,
        exports: {
            admin: {
                auth() {
                    return {
                        async verifyIdToken(token) {
                            if (token === 'bad-token') throw new Error('invalid token');
                            return { uid: 'locked-user', email: 'locked@luum.app' };
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
                                                plan: 'gratuito',
                                                subscription: {
                                                    status: 'trial',
                                                    trialEndsAt: Date.now() - 86400000
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
    const handler = require('../api/ai/[action]');
    const res = response();
    await handler(makeReq(), res);
    assert.equal(res.code, 403);
    assert.ok(res.body.error);
    assert.ok(res.body.entitlement !== undefined);
});

test('query rejeita campo query ausente com 400', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = mockGeminiOk();
    try {
        installMock();
        process.env.GEMINI_API_KEY = 'test-key';
        const handler = require('../api/ai/[action]');
        const res = response();
        await handler(makeReq({ body: { query: '', context: {} } }), res);
        assert.equal(res.code, 400);
        assert.equal(res.body.error, 'query obrigatória');
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test('query rejeita campo query com apenas espaços com 400', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = mockGeminiOk();
    try {
        installMock();
        process.env.GEMINI_API_KEY = 'test-key';
        const handler = require('../api/ai/[action]');
        const res = response();
        await handler(makeReq({ body: { query: '   ', context: {} } }), res);
        assert.equal(res.code, 400);
        assert.equal(res.body.error, 'query obrigatória');
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test('query retorna 200 com answer quando Gemini responde', async () => {
    const expectedAnswer = 'Você trabalhou 5000 segundos hoje, principalmente em VS Code.';
    const originalFetch = globalThis.fetch;
    globalThis.fetch = mockGeminiOk(expectedAnswer);
    try {
        installMock();
        process.env.GEMINI_API_KEY = 'test-key';
        const handler = require('../api/ai/[action]');
        const res = response();
        await handler(makeReq(), res);
        assert.equal(res.code, 200);
        assert.equal(res.body.answer, expectedAnswer);
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test('query retorna 502 quando Gemini retorna erro HTTP', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => ({ ok: false, status: 429, text: async () => 'Too Many Requests' });
    try {
        installMock();
        process.env.GEMINI_API_KEY = 'test-key';
        const handler = require('../api/ai/[action]');
        const res = response();
        await handler(makeReq(), res);
        assert.equal(res.code, 502);
        assert.ok(res.body.error);
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test('query retorna 502 quando Gemini retorna resposta vazia', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => ({
        ok: true,
        text: async () => JSON.stringify({ candidates: [] })
    });
    try {
        installMock();
        process.env.GEMINI_API_KEY = 'test-key';
        const handler = require('../api/ai/[action]');
        const res = response();
        await handler(makeReq(), res);
        assert.equal(res.code, 502);
        assert.equal(res.body.error, 'Gemini retornou resposta vazia');
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test('query retorna 503 quando GEMINI_API_KEY não está configurada', async () => {
    installMock();
    delete process.env.GEMINI_API_KEY;
    const handler = require('../api/ai/[action]');
    const res = response();
    await handler(makeReq(), res);
    assert.equal(res.code, 503);
    assert.equal(res.body.error, 'GEMINI_API_KEY não configurada na Vercel');
    process.env.GEMINI_API_KEY = 'test-key';
});

test('query retorna 405 para método GET', async () => {
    installMock();
    const handler = require('../api/ai/[action]');
    const res = response();
    await handler(makeReq({ method: 'GET' }), res);
    assert.equal(res.code, 405);
});
