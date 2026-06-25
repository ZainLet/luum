'use strict';

const { admin, getFirestore } = require('../_firebaseAdmin');

// GET: retorna a webhookUrl configurada para o usuário
// POST: salva ou remove (body: { webhookUrl: string | null })
module.exports = async (req, res) => {
    if (!['GET', 'POST'].includes(req.method)) return res.status(405).json({ error: 'Method not allowed' });

    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return res.status(401).json({ error: 'Login Firebase obrigatório' });

    let uid;
    try {
        const decoded = await admin.auth().verifyIdToken(authHeader.slice(7));
        uid = decoded.uid;
    } catch {
        return res.status(403).json({ error: 'Token inválido ou expirado' });
    }

    const db = getFirestore();
    const ref = db.collection('zapier_webhooks').doc(uid);

    if (req.method === 'GET') {
        const doc = await ref.get();
        return res.json({ webhookUrl: doc.exists ? (doc.data().webhookUrl || null) : null });
    }

    const { webhookUrl } = req.body || {};
    if (webhookUrl !== null && webhookUrl !== undefined) {
        if (typeof webhookUrl !== 'string' || !webhookUrl.startsWith('https://')) {
            return res.status(400).json({ error: 'webhookUrl deve ser uma URL https://' });
        }
        await ref.set({ webhookUrl, updatedAt: new Date().toISOString() }, { merge: true });
    } else {
        await ref.delete();
    }

    return res.json({ ok: true });
};
