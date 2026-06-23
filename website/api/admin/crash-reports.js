'use strict';

const { admin, getFirestore } = require('../_firebaseAdmin');
const { applyCorsHeaders } = require('../_cors');
const { applySecurityHeaders } = require('../_httpHeaders');
const { assertAdmin } = require('../_adminAuth');

const VALID_STATUSES = ['novo', 'em análise', 'resolvido', 'ignorado'];

module.exports = async (req, res) => {
    applySecurityHeaders(res);
    if (applyCorsHeaders(req, res)) return;

    try {
        await assertAdmin(req);
    } catch (err) {
        return res.status(401).json({ error: err.message || 'Não autorizado.' });
    }

    const db = getFirestore();

    if (req.method === 'GET') {
        const { uid, status, limit: limitStr } = req.query || {};
        const limit = Math.min(parseInt(limitStr) || 100, 500);
        let reports = [];

        if (uid) {
            const snap = await db
                .collection('crashReports')
                .doc(uid)
                .collection('reports')
                .orderBy('timestamp', 'desc')
                .limit(limit)
                .get();
            snap.forEach((doc) => reports.push({ id: doc.id, uid, ...doc.data() }));
        } else {
            const usersSnap = await db.collection('crashReports').listDocuments();
            const perUser = Math.max(5, Math.floor(limit / Math.max(usersSnap.length, 1)));
            await Promise.all(
                usersSnap.map(async (userRef) => {
                    let q = userRef.collection('reports').orderBy('timestamp', 'desc');
                    if (status) q = q.where('status', '==', status);
                    const snap = await q.limit(perUser).get();
                    snap.forEach((doc) =>
                        reports.push({ id: doc.id, uid: userRef.id, ...doc.data() })
                    );
                })
            );
            reports.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
            if (reports.length > limit) reports = reports.slice(0, limit);
        }

        return res.status(200).json({ ok: true, reports, total: reports.length });
    }

    if (req.method === 'PATCH') {
        let body = {};
        try {
            const chunks = [];
            for await (const chunk of req) chunks.push(chunk);
            body = JSON.parse(Buffer.concat(chunks).toString());
        } catch { /* empty body ok */ }

        const { uid, reportId, status } = body;
        if (!uid || !reportId || !status) {
            return res.status(400).json({ error: 'uid, reportId e status são obrigatórios.' });
        }
        if (!VALID_STATUSES.includes(status)) {
            return res.status(400).json({ error: `Status inválido. Use: ${VALID_STATUSES.join(', ')}` });
        }

        await db
            .collection('crashReports')
            .doc(uid)
            .collection('reports')
            .doc(reportId)
            .update({ status, updatedAt: new Date().toISOString() });

        return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ error: 'Método não permitido.' });
};
