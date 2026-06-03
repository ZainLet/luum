const STRIPE_SUBSCRIPTION_FIELDS = Object.freeze([
    'stripeCustomerId',
    'stripeSubscriptionId',
    'stripeSessionId',
    'stripePriceId'
]);

function manualSubscriptionSnapshot({
    status,
    seats,
    currentPeriodEnd,
    adminUser,
    serverTimestamp,
    trialTimestamp
}) {
    return {
        status,
        source: 'manual',
        seats,
        quantity: seats,
        billing: 'manual',
        currentPeriodEnd,
        ...(status === 'trial' ? { trialEndsAt: trialTimestamp || currentPeriodEnd } : {}),
        updatedAt: serverTimestamp,
        grantedAt: serverTimestamp,
        grantedBy: adminUser.uid,
        grantedByEmail: adminUser.email || null
    };
}

function stripeSubscriptionDeletePatch(deleteValue) {
    return Object.fromEntries(
        STRIPE_SUBSCRIPTION_FIELDS.map((field) => [`subscription.${field}`, deleteValue])
    );
}

module.exports = {
    STRIPE_SUBSCRIPTION_FIELDS,
    manualSubscriptionSnapshot,
    stripeSubscriptionDeletePatch
};
