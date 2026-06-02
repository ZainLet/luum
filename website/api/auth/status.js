// ════════════════════════════════════════════════════════
//  Status da Assinatura — Luum
//  Rota: GET /api/auth/status?uid={uid}
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
//  Duas formas:
//    A) Receber um token Firebase ID no header Authorization
//    B) Usar API key secreta compartilhada entre backend e app
//
//  A forma (A) é a mais segura. O app desktop envia:
//    Authorization: Bearer {firebase_id_token}
//  Este endpoint verifica o token e extrai o uid.
//

const { admin, getFirestore } = require('../_firebaseAdmin');

async function statusHandler(req, res) {
    // CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const db = getFirestore();
        // ─── Método A (recomendado): Token Firebase ───
        const authHeader = req.headers.authorization;
        let uid = null;

        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.split('Bearer ')[1];
            try {
                const decoded = await admin.auth().verifyIdToken(token);
                uid = decoded.uid;
            } catch (err) {
                return res.status(401).json({ error: 'Token inválido ou expirado' });
            }
        }

        // ─── Método B (fallback): UID na query ───
        // Apenas usar se o app envia uma API key secreta
        if (!uid) {
            const queryUid = req.query.uid;
            const apiKey = req.query.key || req.headers['x-api-key'];

            if (!queryUid || !apiKey || apiKey !== process.env.API_KEY) {
                return res.status(401).json({ error: 'Não autorizado' });
            }
            uid = queryUid;
        }

        // ─── Consulta Firestore ─────────────────────────
        const doc = await db.collection('users').doc(uid).get();

        if (!doc.exists) {
            return res.json({ locked: true, reason: 'user_not_found' });
        }

        const data = doc.data();
        const sub = data.subscription || {};
        const now = Date.now();

        // ─── Trial (7 dias grátis) ──────────────────────
        if (!sub.status || sub.status === 'trial') {
            const createdAt = data.createdAt?.toMillis();
            const trialEnd = sub.trialEndsAt?.toMillis() || (createdAt ? createdAt + 7 * 24 * 60 * 60 * 1000 : 0);
            const isTrialExpired = !trialEnd || now >= trialEnd;

            return res.json({
                locked: isTrialExpired,
                plan: data.plan || 'essencial',
                trial: !isTrialExpired,
                daysRemaining: isTrialExpired ? 0 : Math.ceil((trialEnd - now) / (24 * 60 * 60 * 1000)),
                reason: isTrialExpired ? 'trial_expired' : null
            });
        }

        // ─── Ativa / cancelando no fim do ciclo ─────────
        if (sub.status === 'active' || sub.status === 'canceling') {
            const end = sub.currentPeriodEnd?.toMillis() || 0;
            const isExpired = !end || now >= end;

            if (isExpired) {
                return res.json({ locked: true, reason: 'expired' });
            }

            return res.json({
                locked: false,
                plan: data.plan || 'essencial',
                trial: false,
                expiresAt: end,
                daysRemaining: Math.ceil((end - now) / (24 * 60 * 60 * 1000)),
                canceling: sub.status === 'canceling'
            });
        }

        // ─── Cancelada / vencida ────────────────────────
        return res.json({
            locked: true,
            reason: sub.status, // 'canceled' | 'past_due'
            plan: data.plan || 'essencial'
        });

    } catch (err) {
        console.error('[Status Error]', err);
        res.status(500).json({ error: 'Internal server error' });
    }
}

module.exports = statusHandler;
module.exports.handler = statusHandler;
