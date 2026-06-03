const { admin, getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { requireAdmin } = require('../_adminAuth');

const VALID_PLANS = new Set(['essencial', 'profissional', 'equipes', 'negocios']);
const VALID_STATUSES = new Set(['trial', 'active', 'canceling', 'canceled', 'past_due']);

function jsonBody(req) {
    if (!req.body) return {};
    if (typeof req.body === 'string') return JSON.parse(req.body || '{}');
    return req.body;
}

async function resolveUser({ uid, email }) {
    if (uid) return admin.auth().getUser(uid);
    if (email) return admin.auth().getUserByEmail(email.trim().toLowerCase());
    throw new Error('Informe email ou uid');
}

function timestampFromDays(days) {
    const parsed = Number(days);
    if (!Number.isFinite(parsed) || parsed <= 0) return null;
    return admin.firestore.Timestamp.fromMillis(Date.now() + parsed * 24 * 60 * 60 * 1000);
}

function userResponse(userRecord, firestoreData = {}) {
    return {
        uid: userRecord.uid,
        email: userRecord.email || null,
        name: userRecord.displayName || firestoreData.name || null,
        disabled: Boolean(userRecord.disabled),
        plan: firestoreData.plan || 'essencial',
        subscription: firestoreData.subscription || { status: 'trial' },
        role: firestoreData.role || 'user',
        luumAdmin: userRecord.customClaims?.luumAdmin === true
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
        const plan = body.plan || 'essencial';
        const status = body.status || 'active';
        const role = body.role || 'user';
        const seats = Number.parseInt(body.seats || '1', 10);
        const currentPeriodEnd = timestampFromDays(body.days || 365);

        if (!VALID_PLANS.has(plan)) {
            return res.status(400).json({ error: 'Plano inválido' });
        }
        if (!VALID_STATUSES.has(status)) {
            return res.status(400).json({ error: 'Status inválido' });
        }
        if (!['user', 'admin'].includes(role)) {
            return res.status(400).json({ error: 'Perfil inválido' });
        }
        if (!Number.isInteger(seats) || seats < 1 || seats > 10000 || !currentPeriodEnd) {
            return res.status(400).json({ error: 'Assentos ou validade inválidos' });
        }

        const userRef = db.collection('users').doc(userRecord.uid);
        const existingUser = await userRef.get();

        await userRef.set({
            uid: userRecord.uid,
            email: userRecord.email || body.email || null,
            name: userRecord.displayName || body.name || null,
            plan,
            role,
            seats,
            subscription: {
                status,
                source: 'manual',
                seats,
                currentPeriodEnd,
                ...(status === 'trial' ? { trialEndsAt: currentPeriodEnd } : {}),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                grantedAt: admin.firestore.FieldValue.serverTimestamp(),
                grantedBy: adminUser.uid,
                grantedByEmail: adminUser.email || null
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(!existingUser.exists ? { createdAt: admin.firestore.FieldValue.serverTimestamp() } : {})
        }, { merge: true });

        const currentClaims = userRecord.customClaims || {};
        const nextClaims = {
            ...currentClaims,
            luumAdmin: role === 'admin'
        };
        await admin.auth().setCustomUserClaims(userRecord.uid, nextClaims);

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

module.exports = adminUsersHandler;
module.exports.handler = adminUsersHandler;
