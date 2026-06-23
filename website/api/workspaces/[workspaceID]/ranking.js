'use strict';

const { admin } = require('../../_firebaseAdmin');
const {
    addCors,
    ensureWorkspace,
    firestoreDate,
    handleOptions,
    jsonBody,
    requireWorkspaceAdmin,
    requireWorkspaceUser,
    routeValue,
    swiftReferenceSeconds,
    validID
} = require('../../_workspace');

function number(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function isAdminUID(workspaceData, uid) {
    const admins = workspaceData?.admins || [];
    return admins.includes(uid) || (!admins.length && workspaceData?.createdBy === uid);
}

// POST — fetch ranking (existing, unchanged contract)
async function handleRanking(req, res, workspaceID) {
    const authenticated = await requireWorkspaceUser(req, res);
    if (!authenticated) return;

    const body = jsonBody(req);
    const workspaceRef = await ensureWorkspace({
        db: authenticated.db,
        uid: authenticated.decoded.uid,
        workspaceID,
        workspaceSecret: body.workspaceSecret
    });
    const [workspace, members] = await Promise.all([
        workspaceRef.get(),
        workspaceRef.collection('members').orderBy('score', 'desc').limit(200).get()
    ]);

    const wsData = workspace.data() || {};
    const uid = authenticated.decoded.uid;

    const entries = members.docs.map((doc) => {
        const data = doc.data() || {};
        return {
            id: doc.id,
            displayName: String(data.memberDisplayName || data.email || 'Membro'),
            roleLabel: String(data.roleLabel || 'Membro'),
            trackedTime: number(data.trackedTime),
            focusTime: number(data.focusTime),
            plannedTime: number(data.plannedTime),
            contextSwitches: Math.max(0, Math.round(number(data.contextSwitches))),
            score: Math.max(0, Math.min(100, Math.round(number(data.score)))),
            isCurrentUser: doc.id === uid,
            isAdmin: isAdminUID(wsData, doc.id)
        };
    });

    return res.json({
        organizationName: wsData.organizationName || null,
        updatedAt: swiftReferenceSeconds(firestoreDate(wsData.updatedAt)),
        isCurrentUserAdmin: isAdminUID(wsData, uid),
        entries
    });
}

// PATCH — admin actions: list | promote | demote | remove
async function handleAdminAction(req, res, workspaceID) {
    const authenticated = await requireWorkspaceUser(req, res);
    if (!authenticated) return;

    const { db, decoded } = authenticated;
    const body = jsonBody(req);
    const { action, targetUID, workspaceSecret } = body;

    // Verify workspace secret + admin status
    const workspaceRef = await ensureWorkspace({
        db,
        uid: decoded.uid,
        workspaceID,
        workspaceSecret
    });
    await requireWorkspaceAdmin(db, workspaceID, decoded.uid);
    const workspace = await workspaceRef.get();
    const wsData = workspace.data() || {};

    if (action === 'list') {
        const members = await workspaceRef.collection('members').orderBy('score', 'desc').limit(200).get();
        const memberList = members.docs.map((doc) => {
            const data = doc.data() || {};
            return {
                id: doc.id,
                displayName: String(data.memberDisplayName || data.email || 'Membro'),
                roleLabel: String(data.roleLabel || 'Membro'),
                trackedTime: number(data.trackedTime),
                score: Math.max(0, Math.min(100, Math.round(number(data.score)))),
                isAdmin: isAdminUID(wsData, doc.id),
                isCurrentUser: doc.id === decoded.uid
            };
        });
        return res.json({ members: memberList });
    }

    if (!targetUID || typeof targetUID !== 'string' || !targetUID.trim()) {
        return res.status(400).json({ message: 'targetUID obrigatório' });
    }
    const target = targetUID.trim();

    if (action === 'promote') {
        await workspaceRef.update({
            admins: admin.firestore.FieldValue.arrayUnion(target),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return res.json({ ok: true });
    }

    if (action === 'demote') {
        if (target === decoded.uid) {
            return res.status(400).json({ message: 'Você não pode se rebaixar.' });
        }
        const currentAdmins = wsData.admins || [];
        if (currentAdmins.length <= 1) {
            return res.status(400).json({ message: 'O workspace precisa ter ao menos um admin.' });
        }
        await workspaceRef.update({
            admins: admin.firestore.FieldValue.arrayRemove(target),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return res.json({ ok: true });
    }

    if (action === 'remove') {
        if (target === decoded.uid) {
            return res.status(400).json({ message: 'Você não pode se remover do workspace.' });
        }
        await workspaceRef.collection('members').doc(target).delete();
        return res.json({ ok: true });
    }

    return res.status(400).json({ message: `Ação desconhecida: ${action}` });
}

async function workspaceRankingHandler(req, res) {
    addCors(req, res);
    if (req.method === 'OPTIONS') return handleOptions(req, res);
    if (req.method !== 'POST' && req.method !== 'PATCH') {
        return res.status(405).json({ message: 'Method not allowed' });
    }

    const workspaceID = routeValue(req, 'workspaceID');
    if (!validID(workspaceID)) {
        return res.status(400).json({ message: 'Workspace ID inválido' });
    }

    try {
        if (req.method === 'POST')  return await handleRanking(req, res, workspaceID);
        if (req.method === 'PATCH') return await handleAdminAction(req, res, workspaceID);
    } catch (error) {
        const statusCode = error.statusCode || 500;
        if (statusCode >= 500) console.error('[Workspace Ranking Error]', error);
        return res.status(statusCode).json({
            message: error.statusCode ? error.message : 'Erro interno no workspace'
        });
    }
}

module.exports = workspaceRankingHandler;
module.exports.handler = workspaceRankingHandler;
