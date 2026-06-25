'use strict';

const { admin } = require('../_firebaseAdmin');

module.exports = async (req, res) => {
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return res.status(401).json({ error: 'Login Firebase obrigatório' });
    try {
        await admin.auth().verifyIdToken(authHeader.slice(7));
    } catch {
        return res.status(401).json({ error: 'Token inválido' });
    }

    const clickupToken = req.headers['x-clickup-token'];
    if (!clickupToken) return res.status(400).json({ error: 'Token ClickUp ausente (x-clickup-token)' });

    const { space_id, list_id, due_date } = req.query;

    let url;
    if (list_id) {
        url = `https://api.clickup.com/api/v2/list/${encodeURIComponent(list_id)}/task?include_closed=false`;
    } else if (space_id) {
        url = `https://api.clickup.com/api/v2/space/${encodeURIComponent(space_id)}/task?include_closed=false`;
    } else {
        const teamsResp = await fetch('https://api.clickup.com/api/v2/team', {
            headers: { Authorization: clickupToken },
        });
        const teamsData = await teamsResp.json();
        if (!teamsResp.ok) return res.status(502).json({ error: 'Falha ao buscar times no ClickUp', detail: teamsData });
        return res.json({ teams: teamsData.teams || [] });
    }

    if (due_date) url += `&due_date_lt=${encodeURIComponent(due_date)}`;

    const tasksResp = await fetch(url, { headers: { Authorization: clickupToken } });
    const tasksData = await tasksResp.json();
    if (!tasksResp.ok) return res.status(502).json({ error: 'Falha ao buscar tasks no ClickUp', detail: tasksData });

    return res.json({ tasks: tasksData.tasks || [] });
};
