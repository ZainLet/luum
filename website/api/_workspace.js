const { admin, getFirestore } = require('./_firebaseAdmin');
const { addCors: addSharedCors, handleOptions: handleSharedOptions } = require('./_cors');
const { entitlementForUser, includesFeature } = require('./_entitlements');
const { jsonBody: sharedJSONBody } = require('./_jsonBody');
const { sameHash, secretHash, validID } = require('./_workspaceSecurity');

const SWIFT_REFERENCE_SECONDS = 978307200;

function addCors(req, res) {
    return addSharedCors(req, res, { methods: 'PUT, POST, OPTIONS' });
}

function handleOptions(req, res) {
    return handleSharedOptions(req, res, { methods: 'PUT, POST, OPTIONS' });
}

function jsonBody(req) {
    return sharedJSONBody(req, 'JSON do workspace inválido');
}

function routeValue(req, name) {
    if (req.query?.[name]) return String(req.query[name]).trim();
    return '';
}

function swiftReferenceSeconds(date) {
    if (!date) return null;
    return date.getTime() / 1000 - SWIFT_REFERENCE_SECONDS;
}

function firestoreDate(value) {
    return value?.toDate?.() || null;
}

async function requireWorkspaceUser(req, res) {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
        res.status(401).json({ message: 'Login Firebase obrigatório para workspace' });
        return null;
    }

    const db = getFirestore();
    let decoded;
    try {
        decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
    } catch {
        res.status(401).json({ message: 'Token Firebase inválido ou expirado' });
        return null;
    }

    const profile = await db.collection('users').doc(decoded.uid).get();
    if (!profile.exists) {
        res.status(403).json({ message: 'Conta Firebase sem perfil Luum' });
        return null;
    }

    const entitlement = entitlementForUser(profile.data());
    if (!includesFeature(entitlement, 'teamWorkspace')) {
        res.status(403).json({ message: 'Seu plano não permite workspace corporativo' });
        return null;
    }

    return { db, decoded, entitlement };
}

async function ensureWorkspace({ db, uid, workspaceID, workspaceSecret, organizationName }) {
    const workspaceRef = db.collection('workspaces').doc(workspaceID);
    const providedHash = secretHash(workspaceSecret);
    if (!providedHash || !String(workspaceSecret || '').trim()) {
        const error = new Error('Chave do workspace obrigatória');
        error.statusCode = 400;
        throw error;
    }

    await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(workspaceRef);
        if (!snap.exists) {
            transaction.set(workspaceRef, {
                organizationName: String(organizationName || 'Minha empresa').trim() || 'Minha empresa',
                secretHash: providedHash,
                createdBy: uid,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            return;
        }

        if (!sameHash(snap.data()?.secretHash, providedHash)) {
            const error = new Error('Chave do workspace inválida');
            error.statusCode = 403;
            throw error;
        }

        transaction.set(workspaceRef, {
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
    });

    return workspaceRef;
}

module.exports = {
    addCors,
    ensureWorkspace,
    firestoreDate,
    handleOptions,
    jsonBody,
    requireWorkspaceUser,
    routeValue,
    sameHash,
    secretHash,
    swiftReferenceSeconds,
    validID
};
