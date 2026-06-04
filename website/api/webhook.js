// Stripe Webhook -> Firestore — Luum

const { admin, getFirestore } = require('./_firebaseAdmin');
const { getStripe, isStripePlan, requireSetting } = require('./_stripe');
const {
    invoiceSubscriptionID,
    invoiceSubscriptionMetadata,
    normalizeStripeStatus,
    planPatch
} = require('./_stripeWebhookShape');

function readRawBody(req) {
    return new Promise((resolve, reject) => {
        const chunks = [];
        req.on('data', chunk => chunks.push(Buffer.from(chunk)));
        req.on('end', () => resolve(Buffer.concat(chunks)));
        req.on('error', reject);
    });
}

async function subscriptionSnapshot(stripe, subscriptionId) {
    if (!subscriptionId) return {};
    const subscription = await stripe.subscriptions.retrieve(subscriptionId);
    const item = subscription.items?.data?.[0];
    return {
        status: subscription.cancel_at_period_end
            ? 'canceling'
            : normalizeStripeStatus(subscription.status),
        currentPeriodStart: admin.firestore.Timestamp.fromMillis(subscription.current_period_start * 1000),
        currentPeriodEnd: admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000),
        billing: subscription.metadata?.billing || (item?.price?.recurring?.interval === 'year' ? 'annually' : 'monthly'),
        quantity: item?.quantity || 1
    };
}

function subscriptionDocumentPatch(plan, subscription) {
    if (plan && !isStripePlan(plan)) {
        console.warn('[Webhook] Ignorando plano Stripe inválido:', plan);
    }

    const patch = {
        ...planPatch(plan, isStripePlan),
        subscription: {
            ...subscription,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }
    };
    return patch;
}

async function writeSubscription(db, uid, plan, subscription) {
    await db.collection('users').doc(uid).set({
        ...subscriptionDocumentPatch(plan, subscription)
    }, { merge: true });
}

async function webhookHandler(req, res) {
    if (req.method !== 'POST') return res.status(405).end();

    const sig = req.headers['stripe-signature'];

    let event;
    try {
        const stripe = await getStripe();
        const endpointSecret = await requireSetting('STRIPE_WEBHOOK_SECRET');
        const rawBody = Buffer.isBuffer(req.body) ? req.body : await readRawBody(req);
        event = stripe.webhooks.constructEvent(rawBody, sig, endpointSecret);
    } catch (err) {
        console.error('[Webhook] Signature verification failed:', err.message);
        return res.status(400).send('Webhook signature verification failed');
    }

    try {
        const db = getFirestore();
        const stripe = await getStripe();
        switch (event.type) {
            case 'checkout.session.completed': {
                const session = event.data.object;
                const uid = session.metadata?.uid;
                const plan = session.metadata?.plan;
                if (!uid || !plan) return res.status(200).end();

                const period = await subscriptionSnapshot(stripe, session.subscription);
                await writeSubscription(db, uid, plan, {
                    status: period.status,
                    stripeCustomerId: session.customer,
                    stripeSubscriptionId: session.subscription,
                    stripeSessionId: session.id,
                    currentPeriodStart: period.currentPeriodStart,
                    currentPeriodEnd: period.currentPeriodEnd,
                    billing: session.metadata?.billing || period.billing,
                    quantity: period.quantity,
                });
                break;
            }

            case 'invoice.payment_succeeded': {
                const invoice = event.data.object;
                const subscriptionId = invoiceSubscriptionID(invoice);
                if (!subscriptionId) break;

                const subscription = await stripe.subscriptions.retrieve(subscriptionId);
                const invoiceMetadata = invoiceSubscriptionMetadata(invoice);
                const uid = subscription.metadata?.uid || invoiceMetadata.uid;
                if (!uid) break;

                const period = await subscriptionSnapshot(stripe, subscriptionId);
                await writeSubscription(db, uid, subscription.metadata?.plan || invoiceMetadata.plan, {
                    status: period.status,
                    stripeSubscriptionId: subscriptionId,
                    currentPeriodStart: period.currentPeriodStart,
                    currentPeriodEnd: period.currentPeriodEnd,
                    billing: subscription.metadata?.billing || invoiceMetadata.billing || period.billing,
                    quantity: period.quantity,
                });
                break;
            }

            case 'customer.subscription.updated': {
                const sub = event.data.object;
                const uid = sub.metadata?.uid;
                if (!uid) break;

                await writeSubscription(db, uid, sub.metadata?.plan, {
                    status: sub.cancel_at_period_end ? 'canceling' : normalizeStripeStatus(sub.status),
                    stripeSubscriptionId: sub.id,
                    currentPeriodStart: admin.firestore.Timestamp.fromMillis(sub.current_period_start * 1000),
                    currentPeriodEnd: admin.firestore.Timestamp.fromMillis(sub.current_period_end * 1000),
                    billing: sub.metadata?.billing || (sub.items?.data?.[0]?.price?.recurring?.interval === 'year' ? 'annually' : 'monthly'),
                    quantity: sub.items?.data?.[0]?.quantity || 1,
                });
                break;
            }

            case 'customer.subscription.deleted': {
                const sub = event.data.object;
                const uid = sub.metadata?.uid;
                if (!uid) break;

                await writeSubscription(db, uid, sub.metadata?.plan, {
                    status: 'canceled',
                    stripeSubscriptionId: sub.id,
                });
                break;
            }
        }

        return res.json({ received: true });
    } catch (err) {
        console.error('[Webhook Error]', err);
        return res.status(500).json({ error: 'Webhook handler failed' });
    }
}

module.exports = webhookHandler;
module.exports.handler = webhookHandler;
module.exports.config = {
    api: {
        bodyParser: false
    }
};
