const PLAN_ALIASES = Object.freeze({
    essential: 'essencial',
    essencial: 'essencial',
    basic: 'essencial',
    basico: 'essencial',
    professional: 'profissional',
    profissional: 'profissional',
    pro: 'profissional',
    team: 'equipes',
    teams: 'equipes',
    equipe: 'equipes',
    equipes: 'equipes',
    business: 'negocios',
    enterprise: 'negocios',
    empresa: 'negocios',
    negocio: 'negocios',
    negocios: 'negocios'
});

const VALID_STATUSES = new Set(['trial', 'active', 'canceling', 'canceled', 'past_due']);
const VALID_ROLES = new Set(['user', 'admin']);

function normalizedKey(value) {
    return String(value || '')
        .trim()
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '');
}

function normalizeAdminPlan(value) {
    return PLAN_ALIASES[normalizedKey(value)] || '';
}

function normalizeAdminStatus(value) {
    const status = normalizedKey(value || 'active');
    return VALID_STATUSES.has(status) ? status : '';
}

function normalizeAdminRole(value) {
    const role = normalizedKey(value || 'user');
    return VALID_ROLES.has(role) ? role : '';
}

function normalizeSeats(value) {
    const seats = Number.parseInt(value || '1', 10);
    return Number.isInteger(seats) && seats >= 1 && seats <= 10000 ? seats : null;
}

module.exports = {
    normalizeAdminPlan,
    normalizeAdminRole,
    normalizeAdminStatus,
    normalizeSeats
};
