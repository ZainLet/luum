const OFFICIAL_ORIGINS = new Set([
    'https://luum-app.web.app',
    'https://luum-app.firebaseapp.com',
    'https://luum-app.vercel.app'
]);

const DEFAULT_ORIGIN = 'https://luum-app.web.app';

function normalizedOrigin(origin) {
    if (!origin) return '';
    try {
        const parsed = new URL(origin);
        return `${parsed.protocol}//${parsed.host}`;
    } catch {
        return '';
    }
}

function allowedOrigin(origin) {
    const normalized = normalizedOrigin(origin);
    return OFFICIAL_ORIGINS.has(normalized) ? normalized : '';
}

function addCors(req, res, { methods = 'GET, POST, OPTIONS' } = {}) {
    const origin = req.headers?.origin || '';
    const allowed = origin ? allowedOrigin(origin) : DEFAULT_ORIGIN;
    if (allowed) {
        res.setHeader('Access-Control-Allow-Origin', allowed);
    }
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods', methods);
    return !origin || Boolean(allowed);
}

function handleOptions(req, res, options = {}) {
    const ok = addCors(req, res, options);
    if (!ok) {
        return res.status(403).json({ error: 'Origin não permitida' });
    }
    return res.status(200).end();
}

module.exports = {
    OFFICIAL_ORIGINS,
    addCors,
    allowedOrigin,
    handleOptions,
    normalizedOrigin
};
