const { admin } = require('../../../_firebaseAdmin');
const {
    addCors,
    ensureWorkspace,
    firestoreDate,
    jsonBody,
    requireWorkspaceUser,
    routeValue,
    swiftReferenceSeconds,
    validID
} = require('../../../_workspace');

function number(value, minimum = 0, maximum = Number.MAX_SAFE_INTEGER) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return minimum;
    return Math.max(minimum, Math.min(maximum, parsed));
}

function text(value, fallback, maximumLength = 160) {
    const normalized = String(value || '').trim();
    return (normalized || fallback).slice(0, maximumLength);
}

function sanitizedPayload(payload) {
    return {
        organizationName: text(payload.organizationName, 'Minha empresa'),
        memberDisplayName: text(payload.memberDisplayName, 'Membro'),
        roleLabel: text(payload.roleLabel, 'Membro', 80),
        trackedTime: number(payload.trackedTime),
        focusTime: number(payload.focusTime),
        plannedTime: number(payload.plannedTime),
        contextSwitches: Math.round(number(payload.contextSwitches, 0, 1_000_000)),
        score: Math.round(number(payload.score, 0, 100)),
        snapshotDay: payload.snapshotDay || null,
        weekStart: payload.weekStart || null,
        weekEnd: payload.weekEnd || null
    };
}

async function workspaceMemberHandler(req, res) {
    addCors(res);
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'PUT') return res.status(405).json({ message: 'Method not allowed' });

    try {
        const workspaceID = routeValue(req, 'workspaceID');
        const memberID = routeValue(req, 'memberID');
        if (!validID(workspaceID) || !validID(memberID)) {
            return res.status(400).json({ message: 'Workspace ID ou Member ID inválido' });
        }

        const authenticated = await requireWorkspaceUser(req, res);
        if (!authenticated) return;

        const body = jsonBody(req);
        if (!body.payload || typeof body.payload !== 'object') {
            return res.status(400).json({ message: 'payload obrigatório' });
        }
        const payload = sanitizedPayload(body.payload);

        const workspaceRef = await ensureWorkspace({
            db: authenticated.db,
            uid: authenticated.decoded.uid,
            workspaceID,
            workspaceSecret: body.workspaceSecret,
            organizationName: payload.organizationName
        });
        const memberRef = workspaceRef.collection('members').doc(authenticated.decoded.uid);

        await memberRef.set({
            ...payload,
            uid: authenticated.decoded.uid,
            requestedMemberID: memberID,
            email: authenticated.decoded.email || null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        const saved = await memberRef.get();
        return res.json({
            updatedAt: swiftReferenceSeconds(firestoreDate(saved.data()?.updatedAt) || new Date())
        });
    } catch (error) {
        console.error('[Workspace Member Error]', error);
        return res.status(error.statusCode || 500).json({
            message: error.statusCode ? error.message : 'Erro interno no workspace'
        });
    }
}

module.exports = workspaceMemberHandler;
module.exports.handler = workspaceMemberHandler;
