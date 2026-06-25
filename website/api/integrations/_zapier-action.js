'use strict';

const { admin, getFirestore } = require('../_firebaseAdmin');

// Sends a summary payload to all configured Zapier webhooks.
// Body: { summary: string, date: string, totalMinutes?: number }
module.exports = async (req, res) => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return res.status(401).json({ error: 'Login Firebase obrigatório' });

    let uid;
    try {
        const decoded = await admin.auth().verifyIdToken(authHeader.slice(7));
        uid = decoded.uid;
    } catch {
        return res.status(403).json({ error: 'Token inválido ou expirado' });
    }

    const { summary, date, totalMinutes } = req.body || {};
    if (!summary || !date) return res.status(400).json({ error: 'Campos obrigatórios: summary, date' });

    const db = getFirestore();
    const doc = await db.collection('zapier_webhooks').doc(uid).get();
    if (!doc.exists) {
        return res.status(404).json({ error: 'Nenhum webhook Zapier configurado para este usuário' });
    }

    const data = doc.data();
    const webhooks = Array.isArray(data.webhooks) ? data.webhooks
        : data.webhookUrl ? [{ url: data.webhookUrl }]
        : [];

    if (webhooks.length === 0) {
        return res.status(404).json({ error: 'Nenhum webhook Zapier configurado para este usuário' });
    }

    const payload = JSON.stringify({ summary, date, totalMinutes: totalMinutes || 0, source: 'luum' });
    const results = await Promise.allSettled(webhooks.map(w =>
        fetch(w.url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: payload,
        }).then(r => r.ok)
    ));

    const succeeded = results.filter(r => r.status === 'fulfilled' && r.value).length;
    if (succeeded === 0) return res.status(502).json({ error: 'Falha ao enviar para todos os webhooks Zapier' });
    return res.json({ ok: true, delivered: succeeded, total: webhooks.length });
};
