const { getAdminApp } = require('../_firebaseAdmin');
const { minimumQuantity, missingStripeEnvNames } = require('../_stripe');
const { getSetting } = require('../_integrationSettings');
const { requireAdmin } = require('../_adminAuth');

function addCors(res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
}

async function stripeHealthHandler(req, res) {
    addCors(res);
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    try {
        getAdminApp();
        const adminUser = await requireAdmin(req, res);
        if (!adminUser) return;

        const missing = await missingStripeEnvNames({ includeWebhook: true });
        return res.json({
            ok: missing.length === 0,
            stripeReady: missing.length === 0,
            missing,
            publicSiteURLConfigured: Boolean(await getSetting('PUBLIC_SITE_URL')),
            minimumSeats: {
                essencial: minimumQuantity('essencial'),
                profissional: minimumQuantity('profissional'),
                equipes: minimumQuantity('equipes'),
                negocios: minimumQuantity('negocios')
            }
        });
    } catch (err) {
        console.error('[Stripe Health Error]', err);
        return res.status(500).json({ error: 'Diagnóstico Stripe falhou. Verifique logs da Vercel.' });
    }
}

module.exports = stripeHealthHandler;
module.exports.handler = stripeHealthHandler;
