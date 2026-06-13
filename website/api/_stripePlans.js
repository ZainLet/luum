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
    equipes: 1,
    negocios: 1
};

function isStripePlan(plan) {
    return Object.prototype.hasOwnProperty.call(PRICE_ENV_BY_PLAN, plan);
}

module.exports = {
    DEFAULT_MINIMUM_QUANTITY_BY_PLAN,
    PRICE_ENV_BY_PLAN,
    isStripePlan
};
