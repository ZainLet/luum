function cancellableStripeSubscriptionID(userData = {}) {
    const subscription = userData.subscription || {};
    if (subscription.source === 'manual') return '';

    const subscriptionID = String(subscription.stripeSubscriptionId || '').trim();
    return /^sub_[A-Za-z0-9]+$/.test(subscriptionID) ? subscriptionID : '';
}

module.exports = { cancellableStripeSubscriptionID };
