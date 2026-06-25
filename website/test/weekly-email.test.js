const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
const reportHelperPath = require.resolve('../api/_weeklyReportEmail');
const weeklyEmailPath = require.resolve('../api/reports/weekly-email');

function response() {
    return {
        body: null, code: 200, headers: {}, setHeader(name, value) { this.headers[name] = value; },
        status(code) { this.code = code; return this; },
        json(body) { this.body = body; return this; },
        end() { return this; }
    };
}

function installFirebaseMock(userData = {}) {
    delete require.cache[firebaseAdminPath];

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
                    collection() {
                        return {
                            doc() {
                                return {
                                    async get() {
                                        return {
                                            exists: userData.exists !== false,
                                            data: () => ({
                                                plan: userData.plan || 'profissional',
                                                email: 'test@luum.app',
                                                subscription: userData.subscription || { status: 'active', currentPeriodEnd: Date.now() + 86400000 }
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

function installReportHelperMock(overrides = {}) {
    delete require.cache[reportHelperPath];

    require.cache[reportHelperPath] = {
        id: reportHelperPath, filename: reportHelperPath, loaded: true,
        exports: {
            cleanEmail(value) {
                const email = String(value || '').trim().toLowerCase();
                return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : '';
            },
            cleanReportPayload(input = {}) {
                return {
                    startDate: input.startDate || '',
                    endDate: input.endDate || '',
                    totalTrackedTime: Number.isFinite(Number(input.totalTrackedTime)) ? Number(input.totalTrackedTime) : 0,
                    averageDailyTrackedTime: Number.isFinite(Number(input.averageDailyTrackedTime)) ? Number(input.averageDailyTrackedTime) : 0,
                    contextSwitches: Math.round(Number(input.contextSwitches) || 0),
                    focusTime: Number.isFinite(Number(input.focusTime)) ? Number(input.focusTime) : 0,
                    distractionTime: Number.isFinite(Number(input.distractionTime)) ? Number(input.distractionTime) : 0,
                    topCategories: Array.isArray(input.topCategories) ? input.topCategories.slice(0, 10) : [],
                    topApps: Array.isArray(input.topApps) ? input.topApps.slice(0, 10) : [],
                    topSites: Array.isArray(input.topSites) ? input.topSites.slice(0, 10) : [],
                    highlights: Array.isArray(input.highlights) ? input.highlights.slice(0, 8).filter(Boolean) : []
                };
            },
            createSimplePDF({ report, narrative }) {
                return Buffer.from('fake-pdf-content');
            },
            async generateNarrative({ report, accountEmail }) {
                if (overrides.generateNarrativeError) throw overrides.generateNarrativeError;
                return {
                    title: 'Resumo semanal Luum',
                    summary: 'Sua semana foi produtiva.',
                    highlights: ['Manteve foco consistente'],
                    recommendations: ['Aumente pausas']
                };
            },
            reportHTML({ narrative, report }) {
                return '<h1>Resumo semanal Luum</h1>';
            },
            async sendReportEmail({ to, subject, html, pdfBuffer, fileName }) {
                if (overrides.sendEmailError) throw overrides.sendEmailError;
                return { id: 'email-123' };
            }
        }
    };
}

const validReport = {
    startDate: '2026-06-15',
    endDate: '2026-06-21',
    totalTrackedTime: 144000,
    averageDailyTrackedTime: 20571,
    contextSwitches: 42,
    focusTime: 108000,
    distractionTime: 36000,
    topCategories: [{ label: 'Trabalho', duration: 72000 }],
    topApps: [{ label: 'VSCode', duration: 54000 }],
    highlights: ['Foco em tarefas importantes']
};

test('weekly-email rejects missing token with 401', async () => {
    installFirebaseMock();
    installReportHelperMock();
    delete require.cache[weeklyEmailPath];
    const handler = require('../api/reports/weekly-email');
    const res = response();
    await handler({
        method: 'POST', headers: {}, body: validReport
    }, res);
    assert.equal(res.code, 401);
    assert.equal(res.body.error, 'Login Firebase obrigatório');
});

test('weekly-email returns health on GET', async () => {
    installFirebaseMock();
    installReportHelperMock();
    delete require.cache[weeklyEmailPath];
    process.env.GEMINI_API_KEY = 'gk-xxx';
    process.env.RESEND_API_KEY = 'rk-xxx';
    process.env.REPORT_EMAIL_FROM = 'luum@luum.app';
    const handler = require('../api/reports/weekly-email');
    const res = response();
    await handler({
        method: 'GET', headers: {}, body: null
    }, res);
    assert.equal(res.code, 200);
    assert.equal(res.body.route, '/api/reports/weekly-email');
    assert.equal(res.body.ok, true);
});

test('weekly-email rejects malformed report with 400', async () => {
    installFirebaseMock();
    installReportHelperMock();
    delete require.cache[weeklyEmailPath];
    const handler = require('../api/reports/weekly-email');
    const res = response();
    await handler({
        method: 'POST',
        headers: { authorization: 'Bearer valid-token' },
        body: { note: 'no report data at all' }
    }, res);
    assert.equal(res.code, 400);
    assert.equal(res.body.error, 'Relatório semanal incompleto');
});

test('weekly-email sends email and returns success', async () => {
    installFirebaseMock();
    installReportHelperMock();
    delete require.cache[weeklyEmailPath];
    const handler = require('../api/reports/weekly-email');
    const res = response();
    await handler({
        method: 'POST',
        headers: { authorization: 'Bearer valid-token' },
        body: validReport
    }, res);
    assert.equal(res.code, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.emailed, true);
    assert.equal(res.body.emailID, 'email-123');
    assert.ok(res.body.fileName);
    assert.ok(res.body.narrative);
});

test('weekly-email returns 502 when email provider fails', async () => {
    installFirebaseMock();
    installReportHelperMock({ sendEmailError: Object.assign(new Error('Resend rejeitou'), { statusCode: 502 }) });
    delete require.cache[weeklyEmailPath];
    const handler = require('../api/reports/weekly-email');
    const res = response();
    await handler({
        method: 'POST',
        headers: { authorization: 'Bearer valid-token' },
        body: validReport
    }, res);
    assert.equal(res.code, 502);
});
