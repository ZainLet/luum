const { admin, getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { profileEmail, profileOnboarding, profileText } = require('../_profileSecurity');

function jsonBody(req) {
    if (!req.body) return {};
    if (typeof req.body === 'string') return JSON.parse(req.body || '{}');
    return req.body;
}

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
        const body = jsonBody(req);
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
        console.error('[Auth Upsert User Error]', err);
        const message = String(err.message || '');
        const isCredentialError = message.includes('credential') ||
            message.includes('Could not load the default credentials');
        return res.status(500).json({
            error: isCredentialError
                ? 'Firebase Admin não configurado na Vercel. Configure FIREBASE_SERVICE_ACCOUNT_JSON.'
                : 'Não foi possível preparar a conta no backend'
        });
    }
}

module.exports = upsertUserHandler;
module.exports.handler = upsertUserHandler;
