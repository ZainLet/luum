const { admin, getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { entitlementForUser, includesFeature } = require('../_entitlements');
const {
    cleanEmail,
    cleanReportPayload,
    createSimplePDF,
    generateNarrative,
    reportHTML,
    sendReportEmail
} = require('../_weeklyReportEmail');

const MAX_REPORT_BODY_BYTES = 80_000;

function configured(value) {
    return typeof value === 'string' && value.trim().length > 0;
}

function weeklyReportHealth() {
    const geminiConfigured = configured(process.env.GEMINI_API_KEY);
    const resendConfigured = configured(process.env.RESEND_API_KEY);
    const fromConfigured = configured(process.env.REPORT_EMAIL_FROM) || configured(process.env.RESEND_FROM_EMAIL);

    return {
        ok: geminiConfigured && resendConfigured && fromConfigured,
        route: '/api/reports/weekly-email',
        gemini: {
            configured: geminiConfigured,
            model: process.env.GEMINI_MODEL || 'gemini-2.5-flash'
        },
        email: {
            provider: 'resend',
            configured: resendConfigured && fromConfigured,
            apiKeyConfigured: resendConfigured,
            fromConfigured
        }
    };
}

function jsonBody(req) {
    if (!req.body) return {};
    if (typeof req.body === 'string') {
        if (Buffer.byteLength(req.body, 'utf8') > MAX_REPORT_BODY_BYTES) {
            const error = new Error('Relatório semanal grande demais');
            error.statusCode = 413;
            throw error;
        }
        try {
            return JSON.parse(req.body || '{}');
        } catch {
            const error = new Error('JSON do relatório semanal inválido');
            error.statusCode = 400;
            throw error;
        }
    }
    return req.body;
}

function reportFileName(report) {
    const start = String(report.startDate || 'weekly').replace(/[^0-9a-z-]+/gi, '-').replace(/-+/g, '-');
    return `luum-weekly-report-${start || 'weekly'}.pdf`;
}

async function requireFirebaseUser(req) {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return null;
    try {
        return await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
    } catch {
        return null;
    }
}

async function weeklyReportEmailHandler(req, res) {
    addCors(req, res, { methods: 'GET, POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'GET, POST, OPTIONS' });
    if (req.method === 'GET') return res.json(weeklyReportHealth());
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const decoded = await requireFirebaseUser(req);
        if (!decoded?.uid) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        const db = getFirestore();
        const profile = await db.collection('users').doc(decoded.uid).get();
        if (!profile.exists) {
            return res.status(403).json({ error: 'Conta Luum não encontrada' });
        }
        const profileData = profile.data();

        const entitlement = entitlementForUser(profileData);
        if (!includesFeature(entitlement, 'weeklyReportEmail')) {
            return res.status(403).json({
                error: 'Relatórios por email exigem o plano Profissional ou maior',
                entitlement
            });
        }

        const body = jsonBody(req);
        const report = cleanReportPayload(body.report || body);
        if (!report.startDate || !report.endDate || !Number.isFinite(report.totalTrackedTime) || report.totalTrackedTime <= 0) {
            return res.status(400).json({ error: 'Relatório semanal incompleto' });
        }

        const to = cleanEmail(decoded.email) || cleanEmail(profileData.email);
        if (!to) {
            return res.status(400).json({ error: 'Email de destino obrigatório' });
        }

        const narrative = await generateNarrative({ report, accountEmail: to });
        const pdfBuffer = createSimplePDF({ report, narrative });
        const fileName = reportFileName(report);
        const shouldSendEmail = body.sendEmail !== false;
        let email = null;

        if (shouldSendEmail) {
            email = await sendReportEmail({
                to,
                subject: narrative.title || 'Resumo semanal Luum',
                html: reportHTML({ narrative, report }),
                pdfBuffer,
                fileName
            });
        }

        return res.json({
            ok: true,
            emailed: shouldSendEmail,
            emailID: email?.id || null,
            fileName,
            narrative,
            pdfBase64: shouldSendEmail ? undefined : pdfBuffer.toString('base64')
        });
    } catch (err) {
        const statusCode = err.statusCode || 500;
        if (statusCode >= 500) {
            console.error('[Weekly Report Email Error]', err);
        }
        return res.status(statusCode).json({
            error: err.statusCode
                ? err.message
                : 'Não foi possível gerar o relatório semanal'
        });
    }
}

module.exports = weeklyReportEmailHandler;
module.exports.handler = weeklyReportEmailHandler;
module.exports._private = {
    MAX_REPORT_BODY_BYTES,
    weeklyReportHealth,
    reportFileName
};
