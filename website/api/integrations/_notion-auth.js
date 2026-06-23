'use strict';

const { admin, getFirestore } = require('../_firebaseAdmin');

module.exports = async (req, res) => {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Login Firebase obrigatório' });
    }
    let uid;
    try {
        const decoded = await admin.auth().verifyIdToken(authHeader.slice(7));
        uid = decoded.uid;
    } catch {
        return res.status(401).json({ error: 'Token inválido' });
    }

    if (req.method === 'POST') {
        const body = req.body || {};
        if (!body.code) {
            return res.status(400).json({ error: 'Código de autorização obrigatório' });
        }
        return res.status(200).json({ ok: true });
    }

    const clientID = process.env.NOTION_INTEGRATION_TOKEN;
    if (!clientID) {
        return res.status(503).json({ error: 'Notion não configurado' });
    }

    const redirectURI = `https://${req.headers.host}/api/integrations?action=notion-auth`;
    const url = `https://api.notion.com/v1/oauth/authorize?client_id=${clientID}&redirect_uri=${encodeURIComponent(redirectURI)}&response_type=code`;
    return res.status(200).json({ url });
};
