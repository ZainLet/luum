const { admin, getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { entitlementForUser } = require('../_entitlements');
const { deviceSecurityPatch, evaluateDeviceAccess, normalizedDeviceID } = require('../_deviceSecurity');
const { jsonBody: sharedJSONBody } = require('../_jsonBody');
const { profileEmail, profileOnboarding, profileText } = require('../_profileSecurity');
const { checkRateLimit } = require('../_rateLimit');

// ── GET /api/auth/status ────────────────────────────────────

async function statusHandler(req, res) {
    addCors(req, res, { methods: 'GET, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'GET, OPTIONS' });
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const rateCheck = checkRateLimit(req, { windowMs: 60_000, max: 20, key: 'auth-status' });
    if (rateCheck.limited) {
        res.setHeader('Retry-After', String(rateCheck.retryAfter));
        return res.status(429).json({ error: 'Muitas requisições. Tente em breve.' });
    }

    try {
        const authHeader = req.headers.authorization || '';
        if (!authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        let uid;
        try {
            const decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
            uid = decoded.uid;
        } catch {
            return res.status(401).json({ error: 'Token inválido ou expirado' });
        }

        const db = getFirestore();
        const userRef = db.collection('users').doc(uid);
        const doc = await userRef.get();

        if (!doc.exists) {
            return res.json({ locked: true, reason: 'user_not_found' });
        }

        const data = doc.data();
        const deviceID = normalizedDeviceID(req);
        if (deviceID) {
            const deviceAccess = evaluateDeviceAccess(data, deviceID);
            if (!deviceAccess.allowed) {
                await userRef.set(deviceSecurityPatch(admin, deviceID, { allowNewDevice: false }), { merge: true });
                return res.json({
                    locked: true,
                    plan: entitlementForUser(data).plan,
                    trial: false,
                    reason: deviceAccess.reason,
                    deviceLimit: deviceAccess.limit
                });
            }
            await userRef.set(deviceSecurityPatch(admin, deviceID), { merge: true });
        }

        return res.json(entitlementForUser(data));
    } catch (err) {
        console.error('[Status Error]', err);
        return res.status(500).json({ error: 'Internal server error' });
    }
}

// ── POST /api/auth/upsert-user ──────────────────────────────

async function upsertUserHandler(req, res) {
    addCors(req, res, { methods: 'POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'POST, OPTIONS' });
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const authHeader = req.headers.authorization || '';
        if (!authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        const db = getFirestore();
        let decoded;
        try {
            decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
        } catch {
            return res.status(401).json({ error: 'Token Firebase inválido ou expirado' });
        }

        const body = sharedJSONBody(req, 'JSON da conta inválido');
        const ref = db.collection('users').doc(decoded.uid);
        const snap = await ref.get();
        const onboarding = profileOnboarding(body.onboarding);

        const baseProfile = {
            uid: decoded.uid,
            email: profileEmail(decoded),
            name: profileText(decoded.name, body.name),
            photoURL: profileText(decoded.picture, body.photoURL, 2048),
            ...(onboarding ? { onboarding, quiz: onboarding } : {}),
            lastLogin: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        if (!snap.exists) {
            await ref.set({
                ...baseProfile,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                plan: 'essencial',
                role: 'user',
                subscription: {
                    status: 'trial',
                    trialEndsAt: admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000)
                }
            }, { merge: true });
        } else {
            await ref.set(baseProfile, { merge: true });
        }

        const saved = await ref.get();
        return res.json({ ok: true, user: saved.data() || null });
    } catch (err) {
        const statusCode = err.statusCode || 500;
        if (statusCode >= 500) console.error('[Auth Upsert User Error]', err);
        const message = String(err.message || '');
        const isCredentialError = message.includes('credential') ||
            message.includes('Could not load the default credentials');
        return res.status(statusCode).json({
            error: err.statusCode
                ? err.message
                : isCredentialError
                ? 'Firebase Admin não configurado na Vercel. Configure FIREBASE_SERVICE_ACCOUNT_JSON.'
                : 'Não foi possível preparar a conta no backend'
        });
    }
}

// ── Router ──────────────────────────────────────────────────

async function handler(req, res) {
    const action = req.query.action;
    if (action === 'status') return statusHandler(req, res);
    if (action === 'upsert-user') return upsertUserHandler(req, res);
    return res.status(404).json({ error: `Ação de autenticação desconhecida: ${action}` });
}

module.exports = handler;
module.exports.handler = handler;
