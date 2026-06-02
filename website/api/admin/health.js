const { admin, getFirestore } = require('../_firebaseAdmin');
const { allowedAdminEmails } = require('../_adminAuth');

function addCors(res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
}

async function adminHealthHandler(req, res) {
    addCors(res);
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const db = getFirestore();
        const authHeader = req.headers.authorization || '';
        if (!authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        const decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
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

module.exports = adminHealthHandler;
module.exports.handler = adminHealthHandler;
