// ════════════════════════════════════════════════════════
//  Stripe Checkout Session — Luum
//  Rota: POST /api/checkout
//  Para Firebase Cloud Functions ou Vercel Serverless
//  ════════════════════════════════════════════════════════
//
//  Funcionamento:
//   1. Front-end chama esta rota com { plan, uid, email }
//   2. Criamos um Stripe Checkout Session
//   3. Stripe redireciona para a página de pagamento
//   4. Após pagamento, Stripe chama o webhook (webhook.js)
//   5. Webhook atualiza o Firestore
//

const { admin, getAdminApp } = require('./_firebaseAdmin');
const { getStripe, getPriceID, minimumQuantity } = require('./_stripe');
const { getSetting } = require('./_integrationSettings');
const { checkoutEmail } = require('./_checkoutSecurity');

async function checkoutHandler(req, res) {
    // CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const { plan, uid, billing = 'monthly', quantity = 1 } = req.body || {};

        if (!plan || !uid) {
            return res.status(400).json({ error: 'plan e uid são obrigatórios' });
        }

        if (!['monthly', 'annually'].includes(billing)) {
            return res.status(400).json({ error: 'Ciclo de cobrança inválido' });
        }

        const parsedQuantity = Number.parseInt(quantity, 10);
        const minQuantity = minimumQuantity(plan);
        if (!Number.isInteger(parsedQuantity) || parsedQuantity < minQuantity || parsedQuantity > 1000) {
            return res.status(400).json({ error: `Quantidade inválida. Use entre ${minQuantity} e 1000.` });
        }

        getAdminApp();
        const authHeader = req.headers.authorization || '';
        if (!authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        const decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
        if (decoded.uid !== uid) {
            return res.status(403).json({ error: 'Usuário do token não confere com checkout' });
        }

        const priceId = await getPriceID(plan, billing);
        if (!priceId) {
            return res.status(400).json({ error: `Preço Stripe ausente para plano "${plan}" (${billing})` });
        }

        const stripe = await getStripe();
        const origin = String(await getSetting('PUBLIC_SITE_URL') || req.headers.origin || '').replace(/\/+$/, '');
        if (!origin || !/^https?:\/\//.test(origin)) {
            return res.status(500).json({ error: 'PUBLIC_SITE_URL ou Origin obrigatório para checkout' });
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
        res.status(500).json({ error: err.message });
    }
}

module.exports = checkoutHandler;
module.exports.handler = checkoutHandler;
