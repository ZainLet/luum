const { admin, getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { entitlementForUser, includesFeature } = require('../_entitlements');

function jsonBody(req) {
    if (!req.body) return {};
    if (typeof req.body === 'string') return JSON.parse(req.body || '{}');
    return req.body;
}

function backupIDFromRequest(req) {
    if (req.query?.backupID) return String(req.query.backupID);
    const path = req.url?.split('?')[0] || '';
    return decodeURIComponent(path.split('/').filter(Boolean).pop() || '');
}

async function requireFirebaseUser(req) {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return null;
    try {
        return await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
    } catch {
        return null;
    }
}

function swiftReferenceSeconds(date) {
    if (!date) return null;
    return date.getTime() / 1000 - 978307200;
}

function firestoreDate(value) {
    return value?.toDate?.() || null;
}

function payloadSize(payload) {
    return Buffer.byteLength(JSON.stringify(payload), 'utf8');
}

async function syncHandler(req, res) {
    addCors(req, res, { methods: 'PUT, POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'PUT, POST, OPTIONS' });
    if (!['PUT', 'POST'].includes(req.method)) {
        return res.status(405).json({ message: 'Method not allowed' });
    }

    try {
        const db = getFirestore();
        const decoded = await requireFirebaseUser(req);
        if (!decoded?.uid) {
            return res.status(401).json({ message: 'Login Firebase obrigatório para backup' });
        }

        const profile = await db.collection('users').doc(decoded.uid).get();
        if (!profile.exists) {
            return res.status(403).json({ message: 'Conta Firebase sem perfil Luum' });
        }

        const entitlement = entitlementForUser(profile.data());
        if (!includesFeature(entitlement, 'cloudBackup')) {
            return res.status(403).json({ message: 'Seu plano não permite backup Firebase' });
        }

        const backupID = backupIDFromRequest(req).trim();
        if (!backupID) {
            return res.status(400).json({ message: 'backupID obrigatório' });
        }
        if (backupID !== decoded.uid) {
            return res.status(403).json({ message: 'O backup deve usar o UID da conta Firebase' });
        }

        const body = jsonBody(req);
        const ref = db
            .collection('users')
            .doc(decoded.uid)
            .collection('backups')
            .doc(backupID);

        if (req.method === 'PUT') {
            if (!body.payload || typeof body.payload !== 'object') {
                return res.status(400).json({ message: 'payload obrigatório' });
            }
            if (payloadSize(body.payload) > 1_000_000) {
                return res.status(413).json({ message: 'Backup excede o limite de 1 MB' });
            }
            if (body.payload.rawActivities != null && !includesFeature(entitlement, 'rawActivityBackup')) {
                return res.status(403).json({ message: 'Atividades brutas exigem o plano Negócios' });
            }

            await ref.set({
                uid: decoded.uid,
                backupID,
                payload: body.payload,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                source: 'macos'
            }, { merge: true });

            const saved = await ref.get();
            const updatedAt = firestoreDate(saved.data()?.updatedAt) || new Date();
            return res.json({
                payload: saved.data()?.payload || null,
                updatedAt: swiftReferenceSeconds(updatedAt)
            });
        }

        const snap = await ref.get();
        if (!snap.exists) {
            return res.json({ payload: null, updatedAt: null });
        }

        const data = snap.data() || {};
        return res.json({
            payload: data.payload || null,
            updatedAt: swiftReferenceSeconds(firestoreDate(data.updatedAt))
        });
    } catch (err) {
        console.error('[Sync Backup Error]', err);
        return res.status(500).json({ message: 'Erro interno no backup Firebase' });
    }
}

module.exports = syncHandler;
module.exports.handler = syncHandler;
