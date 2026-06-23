'use strict';

const stores = new Map();

setInterval(() => {
    const now = Date.now();
    for (const [key, store] of stores) {
        const active = store.filter((e) => now - e < store.windowMs);
        if (active.length === 0) stores.delete(key);
        else stores.set(key, active);
    }
}, 60_000).unref();

function clientKey(req) {
    const forwarded = req.headers['x-forwarded-for'];
    const ip = forwarded ? forwarded.split(',')[0].trim() : req.socket?.remoteAddress || 'unknown';
    const uid = req._uid || (req.headers.authorization || '').slice(0, 20);
    return `${ip}|${uid}`;
}

function checkRateLimit(req, { windowMs, max, key: route }) {
    const storeKey = `${route}:${clientKey(req)}`;
    const now = Date.now();

    if (!stores.has(storeKey)) {
        stores.set(storeKey, []);
    }

    const entries = stores.get(storeKey);
    const active = entries.filter((e) => now - e < windowMs);

    if (active.length >= max) {
        const oldest = active[0];
        const retryAfter = Math.ceil((oldest + windowMs - now) / 1000);
        return { limited: true, retryAfter };
    }

    active.push(now);
    stores.set(storeKey, active);
    return { limited: false };
}

function rateLimitMiddleware({ windowMs, max, key }) {
    return (req, res, next) => {
        const result = checkRateLimit(req, { windowMs, max, key });
        if (result.limited) {
            res.setHeader('Retry-After', String(result.retryAfter));
            return res.status(429).json({ error: 'Muitas requisições. Tente em breve.' });
        }
        return next();
    };
}

function resetAll() {
    stores.clear();
}

module.exports = { checkRateLimit, rateLimitMiddleware, resetAll };
