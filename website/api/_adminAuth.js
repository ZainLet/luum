const { admin } = require('./_firebaseAdmin');

const BOOTSTRAP_ADMIN_EMAILS = ['oluum.app@gmail.com'];

function allowedAdminEmails() {
    return [...new Set([
        ...BOOTSTRAP_ADMIN_EMAILS,
        ...(process.env.ADMIN_EMAILS || '').split(',')
    ].map((email) => email.trim().toLowerCase()).filter(Boolean))];
}

async function requireAdmin(req, res) {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Login Firebase obrigatório' });
        return null;
    }

    let decoded;
    try {
        decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
    } catch {
        res.status(401).json({ error: 'Token Firebase inválido ou expirado' });
        return null;
    }
    const email = (decoded.email || '').toLowerCase();
    const isEnvAdmin = allowedAdminEmails().includes(email);
    const isClaimAdmin = decoded.luumAdmin === true || decoded.admin === true;

    if (!isEnvAdmin && !isClaimAdmin) {
        res.status(403).json({ error: 'Usuário sem permissão de admin' });
        return null;
    }

    return decoded;
}

module.exports = { allowedAdminEmails, requireAdmin };
