const { admin, getFirestore } = require('./_firebaseAdmin');
const { getStripe } = require('./_stripe');

async function cancelSubscriptionHandler(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const authHeader = req.headers.authorization || '';
        if (!authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        const db = getFirestore();
        let decoded;
        try {
            decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
        } catch {
            return res.status(401).json({ error: 'Token Firebase inválido ou expirado' });
        }
        const doc = await db.collection('users').doc(decoded.uid).get();
        const data = doc.exists ? doc.data() : null;
        const subscriptionId = data?.subscription?.stripeSubscriptionId;

        if (!subscriptionId) {
            return res.status(400).json({ error: 'Assinatura Stripe não encontrada' });
        }

        const stripe = await getStripe();
        const subscription = await stripe.subscriptions.update(subscriptionId, {
            cancel_at_period_end: true
        });

        await db.collection('users').doc(decoded.uid).set({
            subscription: {
                status: 'canceling',
                stripeSubscriptionId: subscription.id,
                currentPeriodEnd: admin.firestore.Timestamp.fromMillis(subscription.current_period_end * 1000),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            }
        }, { merge: true });

        return res.json({ ok: true, cancelAtPeriodEnd: true });
    } catch (err) {
        console.error('[Cancel Subscription Error]', err);
        return res.status(500).json({ error: 'Não foi possível cancelar a assinatura agora' });
    }
}

module.exports = cancelSubscriptionHandler;
module.exports.handler = cancelSubscriptionHandler;
