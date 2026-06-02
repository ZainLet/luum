const createStripe = require('stripe');
const { getSetting } = require('./_integrationSettings');

const PRICE_ENV_BY_PLAN = {
    essencial: {
        monthly: 'STRIPE_PRICE_ESSENCIAL_MONTHLY',
        annually: 'STRIPE_PRICE_ESSENCIAL_ANNUALLY'
    },
    profissional: {
        monthly: 'STRIPE_PRICE_PROFISSIONAL_MONTHLY',
        annually: 'STRIPE_PRICE_PROFISSIONAL_ANNUALLY'
    },
    equipes: {
        monthly: 'STRIPE_PRICE_EQUIPES_MONTHLY',
        annually: 'STRIPE_PRICE_EQUIPES_ANNUALLY'
    },
    negocios: {
        monthly: 'STRIPE_PRICE_NEGOCIOS_MONTHLY',
        annually: 'STRIPE_PRICE_NEGOCIOS_ANNUALLY'
    }
};

const DEFAULT_MINIMUM_QUANTITY_BY_PLAN = {
    essencial: 1,
    profissional: 1,
    equipes: 2,
    negocios: 5
};

async function requireSetting(name) {
    const value = await getSetting(name);
    if (!value) throw new Error(`Configuração ausente: ${name}`);
    return value;
}

async function getStripe() {
    return createStripe(await requireSetting('STRIPE_SECRET_KEY'));
}

async function getPriceID(plan, billing) {
    const envName = PRICE_ENV_BY_PLAN[plan]?.[billing];
    return envName ? getSetting(envName) : '';
}

function minimumQuantity(plan) {
    const key = `STRIPE_MIN_SEATS_${String(plan || '').toUpperCase()}`;
    const fallback = DEFAULT_MINIMUM_QUANTITY_BY_PLAN[plan] || 1;
    const parsed = Number.parseInt(process.env[key] || String(fallback), 10);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function isStripePlan(plan) {
    return Object.prototype.hasOwnProperty.call(PRICE_ENV_BY_PLAN, plan);
}

async function missingStripeEnvNames({ includeWebhook = false } = {}) {
    const names = ['STRIPE_SECRET_KEY'];
    if (includeWebhook) names.push('STRIPE_WEBHOOK_SECRET');
    Object.values(PRICE_ENV_BY_PLAN).forEach((billing) => names.push(...Object.values(billing)));
    const resolved = await Promise.all(names.map(async (name) => [name, await getSetting(name)]));
    return resolved.filter(([, value]) => !value).map(([name]) => name);
}

module.exports = {
    PRICE_ENV_BY_PLAN,
    getStripe,
    getPriceID,
    isStripePlan,
    minimumQuantity,
    missingStripeEnvNames,
    requireSetting
};
