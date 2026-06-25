'use strict';

const { admin, getFirestore } = require('../_firebaseAdmin');

function isValidWebhookURL(url) {
    if (typeof url !== 'string') return false;
    if (url.length === 0 || url.length > 2048) return false;
    let parsed;
    try { parsed = new URL(url); } catch { return false; }
    return parsed.protocol === 'https:' && parsed.hostname === 'hooks.zapier.com';
}

function normalizeWebhooks(input) {
    if (!Array.isArray(input) || input.length === 0) return [];
    const seen = new Set();
    return input.filter(w => {
        if (!w || typeof w !== 'object') return false;
        const url = (w.url || '').trim();
        if (!url) return false;
        if (seen.has(url)) return false;
        seen.add(url);
        return true;
    }).map(w => ({
        url: (w.url || '').trim(),
        label: (w.label || '').trim() || 'Webhook',
        events: Array.isArray(w.events) ? w.events.filter(e => typeof e === 'string') : [],
    }));
}

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
        let webhooks = [];
        if (doc.exists) {
            const data = doc.data();
            if (Array.isArray(data.webhooks)) {
                webhooks = data.webhooks;
            } else if (data.webhookUrl) {
                webhooks = [{ url: data.webhookUrl, label: 'Webhook', events: [] }];
            }
        }
        return res.json({ webhooks });
    }

    const body = req.body || {};

    if (body.webhooks !== undefined) {
        if (!Array.isArray(body.webhooks)) {
            return res.status(400).json({ error: 'webhooks deve ser um array' });
        }
        for (const w of body.webhooks) {
            if (!isValidWebhookURL(w.url)) {
                return res.status(400).json({ error: `URL inválida: ${w.url || '(vazia)'}. Deve ser https://hooks.zapier.com` });
            }
        }
        const normalized = normalizeWebhooks(body.webhooks);
        if (normalized.length === 0 && body.webhooks.length > 0) {
            return res.status(400).json({ error: 'Nenhum webhook válido fornecido' });
        }
        if (normalized.length === 0) {
            await ref.delete();
        } else {
            await ref.set({ webhooks: normalized, updatedAt: new Date().toISOString() }, { merge: true });
        }
        return res.json({ ok: true, webhooks: normalized });
    }

    // backward compat: webhookUrl (singular) → array de 1
    const { webhookUrl } = body;
    if (webhookUrl !== null && webhookUrl !== undefined) {
        if (!isValidWebhookURL(webhookUrl)) {
            return res.status(400).json({ error: 'webhookUrl deve ser uma URL https://hooks.zapier.com válida (1-2048 chars)' });
        }
        const normalized = [{ url: webhookUrl.trim(), label: 'Webhook', events: [] }];
        await ref.set({ webhooks: normalized, updatedAt: new Date().toISOString() }, { merge: true });
        return res.json({ ok: true, webhooks: normalized });
    }

    await ref.delete();
    return res.json({ ok: true });
};
