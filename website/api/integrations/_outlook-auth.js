'use strict';

const { admin } = require('../_firebaseAdmin');
const { oauthLog } = require('./_oauthLogger');

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

    const clientID = process.env.OUTLOOK_CLIENT_ID;
    if (!clientID) {
        return res.status(503).json({ error: 'Outlook não configurado no servidor. Configure OUTLOOK_CLIENT_ID.' });
    }

    const host = req.headers.host || 'luum-app.vercel.app';
    const redirectURI = `https://${host}/api/integrations?action=outlook-callback`;
    const scopes = 'offline_access openid profile Calendars.Read Mail.ReadBasic';
    const url = `https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=${encodeURIComponent(clientID)}&response_type=code&redirect_uri=${encodeURIComponent(redirectURI)}&response_mode=query&scope=${encodeURIComponent(scopes)}`;
    oauthLog('outlook', 'auth_start');
    return res.json({ url });
};
