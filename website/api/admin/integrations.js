const { getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { requireAdmin } = require('../_adminAuth');
const { maskedSettings, saveSettings } = require('../_integrationSettings');

function jsonBody(req) {
    if (!req.body) return {};
    if (typeof req.body === 'string') return JSON.parse(req.body || '{}');
    return req.body;
}

async function integrationsHandler(req, res) {
    addCors(req, res, { methods: 'GET, POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'GET, POST, OPTIONS' });
    if (!['GET', 'POST'].includes(req.method)) {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
        getFirestore();
        const adminUser = await requireAdmin(req, res);
        if (!adminUser) return;

        if (req.method === 'POST') {
            await saveSettings(jsonBody(req).updates, adminUser);
        }

        return res.json({ ok: true, settings: await maskedSettings() });
    } catch (err) {
        console.error('[Admin Integrations Error]', err);
        const message = String(err.message || '');
        return res.status(500).json({
            error: message.includes('LUUM_SETTINGS_ENCRYPTION_KEY')
                ? 'Configure LUUM_SETTINGS_ENCRYPTION_KEY na Vercel antes de usar o cofre.'
                : 'Não foi possível salvar as integrações.'
        });
    }
}

module.exports = integrationsHandler;
module.exports.handler = integrationsHandler;
