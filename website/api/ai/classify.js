const { admin, getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { entitlementForUser, includesFeature } = require('../_entitlements');
const { jsonBody } = require('../_jsonBody');

const DEFAULT_GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta';
const DEFAULT_GEMINI_MODEL = 'gemini-2.5-flash';
const ALLOWED_CATEGORY_IDS = new Set([
    'work',
    'entertainment',
    'communication',
    'learning',
    'utilities',
    'uncategorized'
]);

function cleanText(value, maxLength = 180) {
    return String(value || '')
        .trim()
        .replace(/\s+/g, ' ')
        .slice(0, maxLength);
}

function cleanCategories(categories) {
    const source = Array.isArray(categories) ? categories : [];
    const cleaned = source
        .map((category) => ({
            id: cleanText(category && category.id, 48),
            title: cleanText(category && category.title, 80)
        }))
        .filter((category) => ALLOWED_CATEGORY_IDS.has(category.id) && category.title);

    return cleaned.length ? cleaned : [
        { id: 'work', title: 'Trabalho' },
        { id: 'entertainment', title: 'Entretenimento' },
        { id: 'communication', title: 'Comunicacao' },
        { id: 'learning', title: 'Aprendizado' },
        { id: 'utilities', title: 'Utilitarios' },
        { id: 'uncategorized', title: 'Sem categoria' }
    ];
}

function buildPrompt({ kind, label, secondaryLabel, currentCategoryID, categories }) {
    const categoryLines = categories
        .map((category) => `- ${category.id}: ${category.title}`)
        .join('\n');

    return `Voce e o classificador do Luum, um app de produtividade para macOS.
Classifique o alvo em UMA das categorias permitidas, usando conhecimento geral do app/site, nome publico, bundle id, dominio e a provavel descricao web dele.

Categorias permitidas:
${categoryLines}

Alvo:
tipo: ${kind}
nome_ou_dominio: ${label}
detalhe: ${secondaryLabel || 'n/a'}
categoria_atual: ${currentCategoryID || 'sem categoria confiavel'}

Regras:
- Responda apenas JSON valido.
- Use exatamente um categoryID permitido.
- confidence deve ficar entre 0 e 1.
- reason deve ser curta, em portugues, com no maximo 120 caracteres.

Formato:
{"categoryID":"work","confidence":0.82,"reason":"Ambiente de desenvolvimento/produtividade."}`;
}

function extractGeminiText(payload) {
    const candidates = Array.isArray(payload && payload.candidates) ? payload.candidates : [];
    for (const candidate of candidates) {
        const parts = candidate && candidate.content && Array.isArray(candidate.content.parts)
            ? candidate.content.parts
            : [];
        const text = parts.map((part) => part && part.text).filter(Boolean).join('\n').trim();
        if (text) return text;
    }
    return '';
}

function parseResult(text) {
    const raw = String(text || '').trim();
    const match = raw.match(/\{[\s\S]*\}/);
    const json = match ? match[0] : raw;
    return JSON.parse(json);
}

async function classifyHandler(req, res) {
    addCors(req, res, { methods: 'POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'POST, OPTIONS' });
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const authHeader = req.headers.authorization || '';
        if (!authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Login Firebase obrigatório' });
        }

        let decoded;
        try {
            decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
        } catch {
            return res.status(401).json({ error: 'Token Firebase inválido ou expirado' });
        }

        const db = getFirestore();
        const userDoc = await db.collection('users').doc(decoded.uid).get();
        if (!userDoc.exists) {
            return res.status(403).json({ error: 'Conta Luum não encontrada' });
        }

        const entitlement = entitlementForUser(userDoc.data());
        if (!includesFeature(entitlement, 'classification')) {
            return res.status(403).json({ error: 'Plano sem acesso à classificação por IA', entitlement });
        }

        const body = jsonBody(req, 'JSON da classificação inválido');
        const kind = cleanText(body.kind, 24);
        if (kind !== 'application' && kind !== 'domain') {
            return res.status(400).json({ error: 'kind deve ser application ou domain' });
        }

        const label = cleanText(body.label, 180);
        if (!label) {
            return res.status(400).json({ error: 'label obrigatório' });
        }

        const categories = cleanCategories(body.categories);
        const currentCategoryID = cleanText(body.currentCategoryID, 48);
        const apiKey = cleanText(process.env.GEMINI_API_KEY, 4096);
        if (!apiKey) {
            return res.status(500).json({ error: 'GEMINI_API_KEY não configurada na Vercel' });
        }

        const prompt = buildPrompt({
            kind,
            label,
            secondaryLabel: cleanText(body.secondaryLabel, 180),
            currentCategoryID: ALLOWED_CATEGORY_IDS.has(currentCategoryID) ? currentCategoryID : '',
            categories
        });

        const endpoint = cleanText(process.env.GEMINI_ENDPOINT || DEFAULT_GEMINI_ENDPOINT, 512).replace(/\/+$/, '');
        const model = cleanText(process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL, 120);
        const geminiResponse = await fetch(`${endpoint}/models/${encodeURIComponent(model)}:generateContent`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey
            },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: {
                    temperature: 0.1,
                    responseMimeType: 'application/json'
                }
            })
        });

        const responseText = await geminiResponse.text();
        if (!geminiResponse.ok) {
            return res.status(502).json({ error: 'Gemini recusou a classificação', status: geminiResponse.status });
        }

        let result;
        try {
            const payload = JSON.parse(responseText);
            result = parseResult(extractGeminiText(payload));
        } catch {
            return res.status(502).json({ error: 'Resposta Gemini inválida' });
        }

        const categoryID = cleanText(result.categoryID, 48);
        const confidence = Math.min(Math.max(Number(result.confidence) || 0, 0), 1);
        const reason = cleanText(result.reason, 160);

        if (!categories.some((category) => category.id === categoryID)) {
            return res.status(502).json({ error: 'Gemini retornou categoria inválida', categoryID });
        }

        return res.json({ categoryID, confidence, reason });
    } catch (err) {
        const statusCode = err.statusCode || 500;
        if (statusCode >= 500) {
            console.error('[AI Classify Error]', err);
        }
        return res.status(statusCode).json({
            error: err.statusCode ? err.message : 'Não foi possível classificar com IA'
        });
    }
}

module.exports = classifyHandler;
module.exports.handler = classifyHandler;
module.exports._private = {
    buildPrompt,
    cleanCategories,
    parseResult
};
