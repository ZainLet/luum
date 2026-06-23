'use strict';

const { admin } = require('../_firebaseAdmin');
const { jsonBody } = require('../_jsonBody');

module.exports = async (req, res) => {
    if (req.method !== 'POST') {
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

    const body = jsonBody(req, 'Payload inválido');
    const refreshToken = typeof body.refresh_token === 'string' ? body.refresh_token.trim() : '';
    if (!refreshToken) {
        return res.status(400).json({ error: 'refresh_token obrigatório' });
    }

    const clientID = process.env.OUTLOOK_CLIENT_ID;
    const clientSecret = process.env.OUTLOOK_CLIENT_SECRET;
    if (!clientID || !clientSecret) {
        return res.status(503).json({ error: 'Outlook não configurado no servidor' });
    }

    try {
        const requestBody = new URLSearchParams({
            grant_type: 'refresh_token',
            refresh_token: refreshToken,
            client_id: clientID,
            client_secret: clientSecret,
            scope: 'offline_access openid profile Calendars.Read Mail.ReadBasic'
        });

        const tokenRes = await fetch('https://login.microsoftonline.com/common/oauth2/v2.0/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: requestBody.toString()
        });

        const data = await tokenRes.json();

        if (!tokenRes.ok || !data.access_token) {
            return res.status(401).json({ error: data.error || 'token_refresh_failed' });
        }

        return res.json({
            access_token: data.access_token,
            refresh_token: data.refresh_token || refreshToken,
            expires_in: data.expires_in || 3600
        });
    } catch {
        return res.status(500).json({ error: 'Erro ao renovar token Microsoft' });
    }
};
