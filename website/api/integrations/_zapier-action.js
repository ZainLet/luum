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
        return res.status(403).json({ error: 'Token inválido ou expirado' });
    }

    const apiKey = process.env.ZAPIER_API_KEY;
    if (!apiKey) {
        return res.status(403).json({ error: 'Zapier não configurado para este usuário' });
    }

    return res.status(200).json({ ok: true, uid });
};
