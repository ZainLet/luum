'use strict';

const { admin } = require('../_firebaseAdmin');

const LINEAR_API = 'https://api.linear.app/graphql';

const issuesQuery = `
query IssuesByTeam($teamId: String!) {
  issues(filter: {
    team: { id: { eq: $teamId } },
    state: { type: { in: ["started", "unstarted"] } }
  }, first: 50) {
    nodes {
      id
      identifier
      title
      dueDate
      state { name }
      cycle { id }
    }
  }
  team(id: $teamId) {
    cycles(first: 10, filter: { isActive: { eq: true } }) {
      nodes {
        id
        name
        startsAt
        endsAt
      }
    }
  }
}`;

async function linearFetch(token, query, variables) {
    const resp = await fetch(LINEAR_API, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': token.startsWith('Bearer ') ? token : `Bearer ${token}`,
        },
        body: JSON.stringify({ query, variables }),
    });

    const body = await resp.json();

    if (!resp.ok) {
        if (resp.status === 401) throw Object.assign(new Error('Token Linear expirado ou inválido'), { status: 401 });
        throw Object.assign(new Error(body.errors?.[0]?.message || 'Erro na API Linear'), { status: resp.status });
    }

    if (body.errors) {
        throw Object.assign(new Error(body.errors[0].message), { status: 400 });
    }

    return body.data;
}

module.exports = async (req, res) => {
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) return res.status(401).json({ error: 'Login Firebase obrigatório' });

    try {
        await admin.auth().verifyIdToken(authHeader.slice(7));
    } catch {
        return res.status(403).json({ error: 'Token inválido ou expirado' });
    }

    const linearToken = req.headers['x-linear-token'];
    if (!linearToken) return res.status(401).json({ error: 'Token do Linear não fornecido. Conecte o Linear primeiro.' });

    const teamID = req.query.team_id;
    if (!teamID || typeof teamID !== 'string' || !teamID.trim()) {
        return res.status(400).json({ error: 'team_id é obrigatório' });
    }

    try {
        const data = await linearFetch(linearToken, issuesQuery, { teamId: teamID.trim() });

        const issues = (data.issues?.nodes || []).map(n => ({
            id: n.identifier,
            title: n.title || n.identifier,
            state: n.state?.name || 'Unknown',
            dueDate: n.dueDate || null,
            cycleId: n.cycle?.id || null,
        }));

        const cycles = (data.team?.cycles?.nodes || []).map(n => ({
            id: n.id,
            name: n.name || 'Ciclo',
            startsAt: n.startsAt || null,
            endsAt: n.endsAt || null,
        }));

        return res.json({ issues, cycles });
    } catch (err) {
        const status = err.status || 502;
        return res.status(status).json({ error: err.message });
    }
};
