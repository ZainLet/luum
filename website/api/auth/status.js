// ════════════════════════════════════════════════════════
//  Status da Assinatura — Luum
//  Rota: GET /api/auth/status
//  ════════════════════════════════════════════════════════
//
//  O app desktop chama este endpoint para saber se o
//  usuário tem assinatura ativa.
//
//  Respostas:
//    200 { locked: false, plan, trial, expiresAt }
//    200 { locked: true,  reason: "..." }
//    401 { error: "Unauthorized" }
//  ════════════════════════════════════════════════════════
//
//  SEGURANÇA:
//  Este endpoint NÃO deve ser público. Exija autenticação.
//  O app desktop envia:
//    Authorization: Bearer {firebase_id_token}
//  Este endpoint verifica o token e extrai o uid.
//

const { admin, getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { entitlementForUser } = require('../_entitlements');
const { deviceSecurityPatch, evaluateDeviceAccess, normalizedDeviceID } = require('../_deviceSecurity');

async function statusHandler(req, res) {
    addCors(req, res, { methods: 'GET, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'GET, OPTIONS' });
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const db = getFirestore();
        const authHeader = req.headers.authorization || '';
        if (!authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        let uid;
        try {
            const decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
            uid = decoded.uid;
        } catch (err) {
            return res.status(401).json({ error: 'Token inválido ou expirado' });
        }

        // ─── Consulta Firestore ─────────────────────────
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
        res.status(500).json({ error: 'Internal server error' });
    }
}

module.exports = statusHandler;
module.exports.handler = statusHandler;
