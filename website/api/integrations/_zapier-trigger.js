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
    return res.status(200).json({ ok: true });
};
