const {
    addCors,
    ensureWorkspace,
    firestoreDate,
    jsonBody,
    requireWorkspaceUser,
    routeValue,
    swiftReferenceSeconds,
    validID
} = require('../../_workspace');

function number(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

async function workspaceRankingHandler(req, res) {
    addCors(res);
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'POST') return res.status(405).json({ message: 'Method not allowed' });

    try {
        const workspaceID = routeValue(req, 'workspaceID');
        if (!validID(workspaceID)) {
            return res.status(400).json({ message: 'Workspace ID inválido' });
        }

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
                isCurrentUser: doc.id === authenticated.decoded.uid
            };
        });

        return res.json({
            organizationName: workspace.data()?.organizationName || null,
            updatedAt: swiftReferenceSeconds(firestoreDate(workspace.data()?.updatedAt)),
            entries
        });
    } catch (error) {
        console.error('[Workspace Ranking Error]', error);
        return res.status(error.statusCode || 500).json({
            message: error.statusCode ? error.message : 'Erro interno no workspace'
        });
    }
}

module.exports = workspaceRankingHandler;
module.exports.handler = workspaceRankingHandler;
