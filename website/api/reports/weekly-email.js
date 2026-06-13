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

function jsonBody(req) {
    if (!req.body) return {};
    if (typeof req.body === 'string') return JSON.parse(req.body || '{}');
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
    addCors(req, res, { methods: 'POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'POST, OPTIONS' });
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

        const entitlement = entitlementForUser(profile.data());
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

        const to = cleanEmail(body.email) || cleanEmail(decoded.email);
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
        console.error('[Weekly Report Email Error]', err);
        return res.status(err.statusCode || 500).json({
            error: err.message || 'Não foi possível gerar o relatório semanal'
        });
    }
}

module.exports = weeklyReportEmailHandler;
module.exports.handler = weeklyReportEmailHandler;
module.exports._private = {
    reportFileName
};
