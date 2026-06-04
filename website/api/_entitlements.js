const DAY_MS = 24 * 60 * 60 * 1000;

const PLAN_RANK = {
    essencial: 1,
    profissional: 2,
    equipes: 3,
    negocios: 4
};

function timestampMillis(value) {
    if (!value) return 0;
    if (typeof value.toMillis === 'function') return value.toMillis();
    if (typeof value.toDate === 'function') return value.toDate().getTime();
    if (value instanceof Date) return value.getTime();
    if (typeof value === 'number') return value;
    return 0;
}

function normalizedPlan(value) {
    const candidate = String(value || 'essencial')
        .trim()
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '');

    if (candidate === 'professional' || candidate === 'pro') return 'profissional';
    if (candidate === 'team' || candidate === 'teams' || candidate === 'equipe') return 'equipes';
    if (candidate === 'business' || candidate === 'enterprise' || candidate === 'empresa' || candidate === 'negocio') return 'negocios';
    return PLAN_RANK[candidate] ? candidate : 'essencial';
}

function entitlementForUser(data = {}, now = Date.now()) {
    const subscription = data.subscription || {};
    const status = String(subscription.status || 'trial').trim().toLowerCase();
    const plan = normalizedPlan(data.plan);

    if (status === 'trial') {
        const createdAt = timestampMillis(data.createdAt);
        const trialEnd = timestampMillis(subscription.trialEndsAt) || (createdAt ? createdAt + 7 * DAY_MS : 0);
        const locked = !trialEnd || now >= trialEnd;
        return {
            locked,
            plan,
            trial: !locked,
            ...(locked ? {} : { expiresAt: trialEnd, trialEndsAt: trialEnd }),
            daysRemaining: locked ? 0 : Math.ceil((trialEnd - now) / DAY_MS),
            reason: locked ? 'trial_expired' : null
        };
    }

    if (status === 'active' || status === 'canceling') {
        const expiresAt = timestampMillis(subscription.currentPeriodEnd);
        const locked = !expiresAt || now >= expiresAt;
        return {
            locked,
            plan,
            trial: false,
            ...(locked ? {} : { expiresAt, daysRemaining: Math.ceil((expiresAt - now) / DAY_MS) }),
            ...(status === 'canceling' ? { canceling: true } : {}),
            reason: locked ? 'expired' : null
        };
    }

    return {
        locked: true,
        plan,
        trial: false,
        reason: status || 'locked'
    };
}

function includesFeature(entitlement, feature) {
    if (!entitlement || entitlement.locked) return false;
    if (entitlement.trial) return feature !== 'teamWorkspace' && feature !== 'rawActivityBackup';

    const rank = PLAN_RANK[normalizedPlan(entitlement.plan)] || 0;
    switch (feature) {
        case 'classification':
            return true;
        case 'cloudBackup':
            return rank >= PLAN_RANK.profissional;
        case 'rawActivityBackup':
            return rank >= PLAN_RANK.negocios;
        case 'teamWorkspace':
            return rank >= PLAN_RANK.equipes;
        default:
            return false;
    }
}

module.exports = { entitlementForUser, includesFeature, normalizedPlan, timestampMillis };
