// ════════════════════════════════════════════════════════
//  Stripe Checkout Session — Luum
//  Rota: POST /api/checkout
//  Para Firebase Cloud Functions ou Vercel Serverless
//  ════════════════════════════════════════════════════════
//
//  Funcionamento:
//   1. Front-end chama esta rota com { plan, uid, billing, quantity }
//   2. Criamos um Stripe Checkout Session
//   3. Stripe redireciona para a página de pagamento
//   4. Após pagamento, Stripe chama o webhook (webhook.js)
//   5. Webhook atualiza o Firestore
//  O email do checkout vem apenas do Firebase ID token verificado.
//

const { admin, getAdminApp, getFirestore } = require('./_firebaseAdmin');
const { addCors, handleOptions } = require('./_cors');
const { getStripe, getPriceID, isStripePlan, minimumQuantity } = require('./_stripe');
const { getSetting } = require('./_integrationSettings');
const { checkoutEmail, checkoutSiteURL } = require('./_checkoutSecurity');
const { cancellableStripeSubscriptionID } = require('./_subscriptionGuards');

// ── DELETE /api/checkout → cancel subscription ──────────────

async function cancelHandler(req, res) {
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
        const subscriptionId = cancellableStripeSubscriptionID(data);
        if (!subscriptionId) {
            return res.status(400).json({ error: 'Assinatura Stripe ativa não encontrada para esta conta' });
        }
        const stripe = await getStripe();
        const subscription = await stripe.subscriptions.update(subscriptionId, { cancel_at_period_end: true });
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

// ── POST /api/checkout → create checkout session ────────────

async function checkoutHandler(req, res) {
    addCors(req, res, { methods: 'POST, DELETE, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'POST, DELETE, OPTIONS' });
    if (req.method === 'DELETE') return cancelHandler(req, res);
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const authHeader = req.headers.authorization || '';
        if (!authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        getAdminApp();
        let decoded;
        try {
            decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
        } catch {
            return res.status(401).json({ error: 'Token Firebase inválido ou expirado' });
        }

        const { plan, uid, billing = 'monthly', quantity = 1 } = req.body || {};

        if (!plan || !uid) {
            return res.status(400).json({ error: 'plan e uid são obrigatórios' });
        }
        if (!isStripePlan(plan)) {
            return res.status(400).json({ error: 'Plano inválido' });
        }

        if (!['monthly', 'annually'].includes(billing)) {
            return res.status(400).json({ error: 'Ciclo de cobrança inválido' });
        }

        const parsedQuantity = Number.parseInt(quantity, 10);
        const minQuantity = minimumQuantity(plan);
        if (!Number.isInteger(parsedQuantity) || parsedQuantity < minQuantity || parsedQuantity > 1000) {
            return res.status(400).json({ error: `Quantidade inválida. Use entre ${minQuantity} e 1000.` });
        }

        if (decoded.uid !== uid) {
            return res.status(403).json({ error: 'Usuário do token não confere com checkout' });
        }

        const priceId = await getPriceID(plan, billing);
        if (!priceId) {
            return res.status(400).json({ error: `Preço Stripe ausente para plano "${plan}" (${billing})` });
        }

        const stripe = await getStripe();
        const origin = checkoutSiteURL(await getSetting('PUBLIC_SITE_URL'));
        if (!origin) {
            return res.status(500).json({ error: 'PUBLIC_SITE_URL inválida para checkout' });
        }

        const session = await stripe.checkout.sessions.create({
            mode: 'subscription',
            payment_method_types: ['card'],
            customer_email: checkoutEmail(decoded),
            line_items: [{
                price: priceId,
                quantity: parsedQuantity
            }],
            metadata: {
                uid: uid,
                plan: plan,
                billing: billing
            },
            subscription_data: {
                metadata: {
                    uid: uid,
                    plan: plan,
                    billing: billing
                }
            },
            success_url: `${origin}/sucesso.html?session_id={CHECKOUT_SESSION_ID}`,
            cancel_url: `${origin}/index.html#precos`,
            allow_promotion_codes: true
        });

        res.json({ id: session.id, url: session.url });

    } catch (err) {
        console.error('[Checkout Error]', err);
        res.status(500).json({ error: 'Checkout indisponível agora' });
    }
}

module.exports = checkoutHandler;
module.exports.handler = checkoutHandler;
