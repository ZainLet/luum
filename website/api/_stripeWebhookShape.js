function normalizeStripeStatus(status) {
    return status === 'active' || status === 'trialing' ? 'active' : status;
}

function invoiceSubscriptionID(invoice) {
    return invoice.subscription ||
        invoice.parent?.subscription_details?.subscription ||
        invoice.subscription_details?.subscription ||
        null;
}

function invoiceSubscriptionMetadata(invoice) {
    return invoice.parent?.subscription_details?.metadata ||
        invoice.subscription_details?.metadata ||
        invoice.subscription_details?.subscription_details?.metadata ||
        {};
}

function planPatch(plan, isValidPlan) {
    if (!plan) return {};
    if (typeof isValidPlan !== 'function' || !isValidPlan(plan)) return {};
    return { plan };
}

module.exports = {
    invoiceSubscriptionID,
    invoiceSubscriptionMetadata,
    normalizeStripeStatus,
    planPatch
};
