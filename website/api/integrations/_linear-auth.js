'use strict';

const crypto = require('crypto');
const { admin } = require('../_firebaseAdmin');
const { oauthLog } = require('./_oauthLogger');

module.exports = async (req, res) => {
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Login Firebase obrigatório' });
    }
    try {
        await admin.auth().verifyIdToken(authHeader.slice(7));
    } catch {
        return res.status(401).json({ error: 'Token inválido' });
    }

    const clientID = process.env.LINEAR_CLIENT_ID;
    const clientSecret = process.env.LINEAR_CLIENT_SECRET;
    if (!clientID || !clientSecret) {
        return res.status(503).json({ error: 'Linear não configurado' });
    }

    const stateVal = crypto.randomBytes(16).toString('hex');
    const stateHmac = crypto.createHmac('sha256', clientSecret).update(stateVal).digest('hex');
    const state = `${stateVal}.${stateHmac}`;

    const redirectURI = `https://${req.headers.host}/api/integrations?action=linear-callback`;
    const url = `https://linear.app/oauth/authorize?client_id=${clientID}&redirect_uri=${encodeURIComponent(redirectURI)}&response_type=code&scope=read&state=${encodeURIComponent(state)}`;
    oauthLog('linear', 'auth_start');
    return res.status(200).json({ url });
};
