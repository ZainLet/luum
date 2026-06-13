const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const weeklyReportPath = require.resolve('../api/reports/weekly-email');
const helperPath = require.resolve('../api/_weeklyReportEmail');

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

function installFirebaseAdminMock({ userData, decoded = { uid: 'firebase-user', email: 'user@luum.app' }, userExists = true }) {
    delete require.cache[firebaseAdminPath];
    delete require.cache[weeklyReportPath];

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
                            return decoded;
                        }
                    };
                }
            },
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

function activeUser(plan = 'profissional') {
    return {
        plan,
        subscription: {
            status: 'active',
            currentPeriodEnd: Date.now() + 7 * 24 * 60 * 60 * 1000
        }
    };
}

function reportPayload(extra = {}) {
    return {
        startDate: '2026-06-08',
        endDate: '2026-06-14',
        totalTrackedTime: 18_000,
        averageDailyTrackedTime: 3_600,
        contextSwitches: 42,
        focusTime: 10_800,
        distractionTime: 1_800,
        topCategories: [{ label: 'Trabalho', duration: 12_000 }],
        topApps: [{ label: 'Xcode', duration: 7_200 }],
        topSites: [{ label: 'github.com', duration: 2_400 }],
        highlights: ['Boa semana de foco'],
        ...extra
    };
}

function geminiResponse() {
    return JSON.stringify({
        candidates: [{
            content: {
                parts: [{
                    text: JSON.stringify({
                        title: 'Resumo semanal Luum',
                        summary: 'Sua semana teve boa concentração e poucas distrações.',
                        highlights: ['Foco consistente', 'GitHub apareceu entre os sites úteis'],
                        recommendations: ['Proteja dois blocos de foco na próxima semana']
                    })
                }]
            }
        }]
    });
}

test('weekly report helper creates a PDF buffer', () => {
    const { cleanReportPayload, createSimplePDF, parseNarrative } = require('../api/_weeklyReportEmail');
    const report = cleanReportPayload(reportPayload());
    const narrative = parseNarrative(JSON.stringify({
        title: 'Resumo semanal Luum',
        summary: 'Semana objetiva.',
        highlights: ['Foco alto'],
        recommendations: ['Manter rotina']
    }));

    const pdf = createSimplePDF({ report, narrative });

    assert.equal(Buffer.isBuffer(pdf), true);
    assert.equal(pdf.subarray(0, 8).toString(), '%PDF-1.4');
});

test('weekly report email requires Firebase auth', async () => {
    installFirebaseAdminMock({ userData: activeUser() });
    const handler = require('../api/reports/weekly-email');
    const res = response();

    await handler({
        method: 'POST',
        headers: { origin: 'https://luum-app.web.app' },
        body: { report: reportPayload() }
    }, res);

    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Login Firebase obrigatório');
});

test('weekly report email enforces Profissional or higher for paid plans', async () => {
    installFirebaseAdminMock({ userData: activeUser('essencial') });
    const handler = require('../api/reports/weekly-email');
    const res = response();

    await handler({
        method: 'POST',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: { report: reportPayload(), sendEmail: false }
    }, res);

    assert.equal(res.code, 403);
    assert.match(res.body.error, /Profissional/);
});

test('weekly report endpoint generates a PDF preview with Gemini', async (t) => {
    installFirebaseAdminMock({ userData: activeUser('profissional') });
    const originalFetch = global.fetch;
    const originalKey = process.env.GEMINI_API_KEY;
    process.env.GEMINI_API_KEY = 'test-gemini-key';
    t.after(() => {
        global.fetch = originalFetch;
        process.env.GEMINI_API_KEY = originalKey;
        delete require.cache[weeklyReportPath];
        delete require.cache[helperPath];
    });

    global.fetch = async (url, options) => {
        assert.match(url, /generativelanguage\.googleapis\.com/);
        assert.equal(options.headers['x-goog-api-key'], 'test-gemini-key');
        return {
            ok: true,
            async text() {
                return geminiResponse();
            }
        };
    };

    const handler = require('../api/reports/weekly-email');
    const res = response();
    await handler({
        method: 'POST',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: { report: reportPayload(), sendEmail: false }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.emailed, false);
    assert.equal(res.body.fileName, 'luum-weekly-report-2026-06-08.pdf');
    assert.equal(Buffer.from(res.body.pdfBase64, 'base64').subarray(0, 8).toString(), '%PDF-1.4');
});

test('weekly report endpoint sends email through Resend when configured', async (t) => {
    installFirebaseAdminMock({ userData: activeUser('negocios') });
    const originalFetch = global.fetch;
    const originalGemini = process.env.GEMINI_API_KEY;
    const originalResend = process.env.RESEND_API_KEY;
    const originalFrom = process.env.REPORT_EMAIL_FROM;
    process.env.GEMINI_API_KEY = 'test-gemini-key';
    process.env.RESEND_API_KEY = 'test-resend-key';
    process.env.REPORT_EMAIL_FROM = 'Luum <reports@luum.app>';
    t.after(() => {
        global.fetch = originalFetch;
        process.env.GEMINI_API_KEY = originalGemini;
        process.env.RESEND_API_KEY = originalResend;
        process.env.REPORT_EMAIL_FROM = originalFrom;
        delete require.cache[weeklyReportPath];
        delete require.cache[helperPath];
    });

    const calls = [];
    global.fetch = async (url, options) => {
        calls.push({ url, options });
        if (String(url).includes('generativelanguage.googleapis.com')) {
            return { ok: true, async text() { return geminiResponse(); } };
        }
        assert.equal(url, 'https://api.resend.com/emails');
        const body = JSON.parse(options.body);
        assert.deepEqual(body.to, ['user@luum.app']);
        assert.equal(body.attachments[0].filename, 'luum-weekly-report-2026-06-08.pdf');
        assert.equal(Buffer.from(body.attachments[0].content, 'base64').subarray(0, 8).toString(), '%PDF-1.4');
        return { ok: true, async json() { return { id: 'email_123' }; } };
    };

    const handler = require('../api/reports/weekly-email');
    const res = response();
    await handler({
        method: 'POST',
        headers: {
            authorization: 'Bearer valid-token',
            origin: 'https://luum-app.web.app'
        },
        body: { report: reportPayload() }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.emailed, true);
    assert.equal(res.body.emailID, 'email_123');
    assert.equal(calls.length, 2);
});
