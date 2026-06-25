'use strict';

const { admin } = require('../_firebaseAdmin');

module.exports = async (req, res) => {
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return res.status(401).json({ error: 'Login Firebase obrigatório' });
    try {
        await admin.auth().verifyIdToken(authHeader.slice(7));
    } catch {
        return res.status(401).json({ error: 'Token inválido' });
    }

    const clientID = process.env.CLICKUP_CLIENT_ID;
    if (!clientID) return res.status(503).json({ error: 'ClickUp não configurado no servidor' });

    const host = req.headers.host || 'luum-app.vercel.app';
    const redirectURI = `https://${host}/api/integrations?action=clickup-callback`;
    const url = `https://app.clickup.com/api?client_id=${encodeURIComponent(clientID)}&redirect_uri=${encodeURIComponent(redirectURI)}`;
    return res.json({ url });
};
