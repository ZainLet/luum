'use strict';

const { admin } = require('../_firebaseAdmin');

module.exports = async (req, res) => {
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
    if (!clientID) {
        return res.status(503).json({ error: 'Linear não configurado' });
    }

    const redirectURI = `https://${req.headers.host}/api/integrations?action=linear-auth`;
    const url = `https://linear.app/oauth/authorize?client_id=${clientID}&redirect_uri=${encodeURIComponent(redirectURI)}&response_type=code&scope=read`;
    return res.status(200).json({ url });
};
