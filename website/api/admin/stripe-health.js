const { getAdminApp } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { getStripe, minimumQuantity, missingStripeEnvNames } = require('../_stripe');
const { getSetting, maskedSettings, saveSettings, SETTINGS } = require('../_integrationSettings');
const { requireAdmin } = require('../_adminAuth');
const { PUBLIC_SITE_URL, webhookURL } = require('../_publicConfig');

const WEBHOOK_URL = webhookURL('/api/webhook');
const WEBHOOK_EVENTS = [
    'checkout.session.completed',
    'invoice.payment_succeeded',
    'customer.subscription.updated',
    'customer.subscription.deleted'
];

function jsonBody(req) {
    if (!req.body) return {};
    if (typeof req.body === 'string') return JSON.parse(req.body || '{}');
    return req.body;
}

function cleanPriceUpdates(input = {}) {
    const updates = {};
    for (const [key, value] of Object.entries(input)) {
        if (!SETTINGS[key] || !key.startsWith('STRIPE_PRICE_')) continue;
        const priceID = String(value || '').trim();
        if (!/^price_[A-Za-z0-9]+$/.test(priceID)) {
            const error = new Error(`Price ID inválido: ${key}`);
            error.statusCode = 400;
            throw error;
        }
        updates[key] = priceID;
    }
    return updates;
}

async function stripeHealthHandler(req, res) {
    addCors(req, res, { methods: 'GET, POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'GET, POST, OPTIONS' });
    if (!['GET', 'POST'].includes(req.method)) return res.status(405).json({ error: 'Method not allowed' });

    try {
        getAdminApp();
        const adminUser = await requireAdmin(req, res);
        if (!adminUser) return;

        if (req.method === 'POST') {
            const body = jsonBody(req);
            const updates = {
                ...cleanPriceUpdates(body.priceUpdates),
                PUBLIC_SITE_URL
            };

            let webhookCreated = false;
            let webhookConfigured = Boolean(await getSetting('STRIPE_WEBHOOK_SECRET'));
            if (!webhookConfigured && body.createWebhook !== false) {
                const stripe = await getStripe();
                const endpoint = await stripe.webhookEndpoints.create({
                    url: WEBHOOK_URL,
                    enabled_events: WEBHOOK_EVENTS
                });
                if (!endpoint.secret) {
                    throw new Error('Stripe não retornou o segredo do webhook recém-criado.');
                }
                updates.STRIPE_WEBHOOK_SECRET = endpoint.secret;
                webhookCreated = true;
                webhookConfigured = true;
            }

            await saveSettings(updates, adminUser);
            return res.json({
                ok: true,
                webhookCreated,
                webhookConfigured,
                webhookURL: WEBHOOK_URL,
                settings: await maskedSettings()
            });
        }

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
        return res.status(err.statusCode || 500).json({
            error: err.statusCode ? err.message : 'Diagnóstico Stripe falhou. Verifique logs da Vercel.'
        });
    }
}

module.exports = stripeHealthHandler;
module.exports.handler = stripeHealthHandler;
