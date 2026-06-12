const { admin, getAdminApp, getFirestore } = require('./_firebaseAdmin');
const { addCors, handleOptions } = require('./_cors');
const { claimsForAdminRole } = require('./_adminClaims');
const { allowedAdminEmails, requireAdmin } = require('./_adminAuth');
const { accountPlan } = require('./_entitlements');
const {
    normalizeAdminPlan,
    normalizeAdminRole,
    normalizeAdminStatus,
    normalizeSeats
} = require('./_adminGrantInput');
const { getStripe, minimumQuantity, missingStripeEnvNames } = require('./_stripe');
const { getSetting, maskedSettings, saveSettings, SETTINGS } = require('./_integrationSettings');
const { manualSubscriptionSnapshot, stripeSubscriptionDeletePatch } = require('./_manualGrant');
const { PUBLIC_SITE_URL, webhookURL } = require('./_publicConfig');

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

function routeAction(req) {
    const value = req.query?.action;
    return String(Array.isArray(value) ? value[0] : value || '').trim();
}

async function adminHealthHandler(req, res) {
    addCors(req, res, { methods: 'GET, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'GET, OPTIONS' });
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const db = getFirestore();
        const authHeader = req.headers.authorization || '';
        if (!authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        let decoded;
        try {
            decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
        } catch {
            return res.status(401).json({ error: 'Token Firebase inválido ou expirado' });
        }

        const email = (decoded.email || '').toLowerCase();
        const adminEmails = allowedAdminEmails();
        const isEnvAdmin = adminEmails.includes(email);
        const isClaimAdmin = decoded.luumAdmin === true || decoded.admin === true;

        await db.collection('users').limit(1).get();

        return res.json({
            ok: true,
            uid: decoded.uid,
            email,
            adminAllowed: isEnvAdmin || isClaimAdmin,
            adminByEmail: isEnvAdmin,
            adminByClaim: isClaimAdmin,
            adminEmailsConfigured: adminEmails.length > 0,
            firebaseAdminReady: true,
            firestoreReady: true
        });
    } catch (err) {
        console.error('[Admin Health Error]', err);
        const message = String(err.message || '');
        const isCredentialError = message.includes('credential') ||
            message.includes('Could not load the default credentials');

        return res.status(500).json({
            ok: false,
            firebaseAdminReady: !isCredentialError,
            firestoreReady: false,
            adminEmailsConfigured: allowedAdminEmails().length > 0,
            error: isCredentialError
                ? 'Firebase Admin não configurado na Vercel. Configure FIREBASE_SERVICE_ACCOUNT_JSON.'
                : 'Admin health falhou. Verifique logs da Vercel.'
        });
    }
}

async function resolveUser({ uid, email }) {
    const trimmedUID = String(uid || '').trim();
    const trimmedEmail = String(email || '').trim().toLowerCase();
    if (trimmedUID) return admin.auth().getUser(trimmedUID);
    if (trimmedEmail) return admin.auth().getUserByEmail(trimmedEmail);
    throw new Error('Informe email ou uid');
}

function timestampFromDays(days) {
    const parsed = Number(days);
    if (!Number.isFinite(parsed) || parsed <= 0) return null;
    return admin.firestore.Timestamp.fromMillis(Date.now() + parsed * 24 * 60 * 60 * 1000);
}

function userResponse(userRecord, firestoreData = {}) {
    const plan = accountPlan(firestoreData);
    const devices = firestoreData.security?.devices;
    const deviceCount = devices && typeof devices === 'object' && !Array.isArray(devices)
        ? Object.keys(devices).length
        : 0;
    return {
        uid: userRecord.uid,
        email: userRecord.email || null,
        name: userRecord.displayName || firestoreData.name || null,
        disabled: Boolean(userRecord.disabled),
        plan,
        storedPlan: firestoreData.plan || null,
        legacyOnboardingPlan: firestoreData.onboarding?.plan || firestoreData.quiz?.plan || null,
        subscription: firestoreData.subscription || { status: 'trial' },
        role: firestoreData.role || 'user',
        luumAdmin: userRecord.customClaims?.luumAdmin === true,
        security: {
            deviceCount,
            lastDeviceSeenAt: firestoreData.security?.lastDeviceSeenAt || null,
            devicesClearedAt: firestoreData.security?.devicesClearedAt || null
        }
    };
}

async function adminUsersHandler(req, res) {
    addCors(req, res, { methods: 'GET, POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'GET, POST, OPTIONS' });
    if (!['GET', 'POST'].includes(req.method)) {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
        const db = getFirestore();
        const adminUser = await requireAdmin(req, res);
        if (!adminUser) return;

        if (req.method === 'GET') {
            const userRecord = await resolveUser({
                uid: req.query.uid,
                email: req.query.email
            });
            const snap = await db.collection('users').doc(userRecord.uid).get();
            return res.json({ user: userResponse(userRecord, snap.exists ? snap.data() : {}) });
        }

        const body = jsonBody(req);
        const userRecord = await resolveUser(body);
        if (body.action === 'clearDevices') {
            const userRef = db.collection('users').doc(userRecord.uid);
            const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();
            await userRef.set({
                security: {
                    devices: admin.firestore.FieldValue.delete(),
                    lastDeviceID: admin.firestore.FieldValue.delete(),
                    lastDeviceSeenAt: admin.firestore.FieldValue.delete(),
                    devicesClearedAt: serverTimestamp,
                    devicesClearedBy: adminUser.uid,
                    devicesClearedByEmail: adminUser.email || null
                },
                updatedAt: serverTimestamp
            }, { merge: true });

            const snap = await userRef.get();
            const refreshed = await admin.auth().getUser(userRecord.uid);
            return res.json({ ok: true, user: userResponse(refreshed, snap.data() || {}) });
        }

        const plan = normalizeAdminPlan(body.plan || 'essencial');
        const status = normalizeAdminStatus(body.status || 'active');
        const role = normalizeAdminRole(body.role || 'user');
        const seats = normalizeSeats(body.seats || '1');
        const currentPeriodEnd = timestampFromDays(body.days || 365);

        if (!plan) return res.status(400).json({ error: 'Plano inválido' });
        if (!status) return res.status(400).json({ error: 'Status inválido' });
        if (!role) return res.status(400).json({ error: 'Perfil inválido' });
        if (!seats || !currentPeriodEnd) {
            return res.status(400).json({ error: 'Assentos ou validade inválidos' });
        }

        const userRef = db.collection('users').doc(userRecord.uid);
        const existingUser = await userRef.get();
        const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

        await userRef.set({
            uid: userRecord.uid,
            email: userRecord.email || body.email || null,
            name: userRecord.displayName || body.name || null,
            plan,
            role,
            seats,
            subscription: manualSubscriptionSnapshot({
                status,
                seats,
                currentPeriodEnd,
                adminUser,
                serverTimestamp
            }),
            updatedAt: serverTimestamp,
            ...(!existingUser.exists ? { createdAt: serverTimestamp } : {})
        }, { merge: true });
        await userRef.update(stripeSubscriptionDeletePatch(admin.firestore.FieldValue.delete()));

        await admin.auth().setCustomUserClaims(
            userRecord.uid,
            claimsForAdminRole(userRecord.customClaims || {}, role)
        );

        const snap = await db.collection('users').doc(userRecord.uid).get();
        const refreshed = await admin.auth().getUser(userRecord.uid);
        return res.json({ ok: true, user: userResponse(refreshed, snap.data() || {}) });
    } catch (err) {
        console.error('[Admin Users Error]', err);
        const code = err.code === 'auth/user-not-found' ? 404 : 500;
        const message = String(err.message || '');
        const isCredentialError = message.includes('credential') ||
            message.includes('Could not load the default credentials') ||
            message.includes('FIREBASE_SERVICE_ACCOUNT_JSON');
        return res.status(code).json({
            error: code === 404
                ? 'Usuário não encontrado no Firebase Auth'
                : (isCredentialError
                    ? 'Firebase Admin não configurado na Vercel. Configure FIREBASE_SERVICE_ACCOUNT_JSON.'
                    : 'Erro interno no admin')
        });
    }
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

async function adminActionHandler(req, res) {
    switch (routeAction(req)) {
        case 'health':
            return adminHealthHandler(req, res);
        case 'users':
            return adminUsersHandler(req, res);
        case 'integrations':
            return integrationsHandler(req, res);
        case 'stripe-health':
            return stripeHealthHandler(req, res);
        default:
            addCors(req, res, { methods: 'GET, POST, OPTIONS' });
            if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'GET, POST, OPTIONS' });
            return res.status(404).json({ error: 'Admin action not found' });
    }
}

module.exports = {
    adminActionHandler,
    adminHealthHandler,
    adminUsersHandler,
    integrationsHandler,
    stripeHealthHandler,
    userResponse
};
