'use strict';

const { admin } = require('../_firebaseAdmin');

module.exports = async (req, res) => {
    if (req.method !== 'GET') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Login Firebase obrigatório' });
    }
    try {
        await admin.auth().verifyIdToken(authHeader.slice(7));
    } catch {
        return res.status(401).json({ error: 'Token Firebase inválido ou expirado' });
    }

    const clientID = process.env.NOTION_CLIENT_ID;
    if (!clientID) {
        return res.status(503).json({ error: 'Notion não configurado no servidor. Configure NOTION_CLIENT_ID.' });
    }

    const host = req.headers.host || 'luum-app.vercel.app';
    const redirectURI = `https://${host}/api/integrations?action=notion-callback`;
    const url = `https://api.notion.com/v1/oauth/authorize?client_id=${encodeURIComponent(clientID)}&redirect_uri=${encodeURIComponent(redirectURI)}&response_type=code&owner=user`;
    return res.json({ url });
};
