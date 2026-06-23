const { admin, getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { entitlementForUser, includesFeature } = require('../_entitlements');
const { jsonBody } = require('../_jsonBody');
const { checkRateLimit } = require('../_rateLimit');

const DEFAULT_GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta';
const DEFAULT_GEMINI_MODEL = 'gemini-2.5-flash';
const EXTERNAL_REQUEST_TIMEOUT_MS = 20_000;

// ── Shared helpers ──────────────────────────────────────────

function cleanText(value, maxLength = 180) {
    return String(value || '')
        .trim()
        .replace(/\s+/g, ' ')
        .slice(0, maxLength);
}

function extractGeminiText(payload) {
    const candidates = Array.isArray(payload?.candidates) ? payload.candidates : [];
    for (const candidate of candidates) {
        const parts = Array.isArray(candidate?.content?.parts) ? candidate.content.parts : [];
        const text = parts.map((p) => p?.text).filter(Boolean).join('\n').trim();
        if (text) return text;
    }
    return '';
}

async function verifyFirebaseAndEntitlement(req, res) {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Login Firebase obrigatório' });
        return null;
    }
    let decoded;
    try {
        decoded = await admin.auth().verifyIdToken(authHeader.slice('Bearer '.length));
    } catch {
        res.status(401).json({ error: 'Token Firebase inválido ou expirado' });
        return null;
    }
    const db = getFirestore();
    const userDoc = await db.collection('users').doc(decoded.uid).get();
    if (!userDoc.exists) {
        res.status(403).json({ error: 'Conta Luum não encontrada' });
        return null;
    }
    const entitlement = entitlementForUser(userDoc.data());
    if (!includesFeature(entitlement, 'classification')) {
        res.status(403).json({ error: 'Plano sem acesso à IA', entitlement });
        return null;
    }
    return { decoded, entitlement };
}

function geminiConfig() {
    const apiKey = cleanText(process.env.GEMINI_API_KEY, 4096);
    const endpoint = cleanText(process.env.GEMINI_ENDPOINT || DEFAULT_GEMINI_ENDPOINT, 512).replace(/\/+$/, '');
    const model = cleanText(process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL, 120);
    return { apiKey, endpoint, model };
}

// ── classify (/api/ai/classify) ─────────────────────────────

const ALLOWED_CATEGORY_IDS = new Set([
    'work', 'entertainment', 'communication', 'learning', 'utilities', 'uncategorized'
]);

function cleanCategories(categories) {
    const source = Array.isArray(categories) ? categories : [];
    const cleaned = source
        .map((c) => ({ id: cleanText(c?.id, 48), title: cleanText(c?.title, 80) }))
        .filter((c) => ALLOWED_CATEGORY_IDS.has(c.id) && c.title);
    return cleaned.length ? cleaned : [
        { id: 'work', title: 'Trabalho' },
        { id: 'entertainment', title: 'Entretenimento' },
        { id: 'communication', title: 'Comunicacao' },
        { id: 'learning', title: 'Aprendizado' },
        { id: 'utilities', title: 'Utilitarios' },
        { id: 'uncategorized', title: 'Sem categoria' }
    ];
}

function buildClassifyPrompt({ kind, label, secondaryLabel, currentCategoryID, categories }) {
    const categoryLines = categories.map((c) => `- ${c.id}: ${c.title}`).join('\n');
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

function parseClassifyResult(text) {
    const raw = String(text || '').trim();
    const match = raw.match(/\{[\s\S]*\}/);
    return JSON.parse(match ? match[0] : raw);
}

async function classifyHandler(req, res) {
    addCors(req, res, { methods: 'POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'POST, OPTIONS' });
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    const rateCheck = checkRateLimit(req, { windowMs: 60_000, max: 30, key: 'ai-classify' });
    if (rateCheck.limited) {
        res.setHeader('Retry-After', String(rateCheck.retryAfter));
        return res.status(429).json({ error: 'Muitas requisições. Tente em breve.' });
    }

    try {
        const auth = await verifyFirebaseAndEntitlement(req, res);
        if (!auth) return;

        const body = jsonBody(req, 'JSON da classificação inválido');
        const kind = cleanText(body.kind, 24);
        if (kind !== 'application' && kind !== 'domain') {
            return res.status(400).json({ error: 'kind deve ser application ou domain' });
        }
        const label = cleanText(body.label, 180);
        if (!label) return res.status(400).json({ error: 'label obrigatório' });

        const categories = cleanCategories(body.categories);
        const currentCategoryID = cleanText(body.currentCategoryID, 48);
        const { apiKey, endpoint, model } = geminiConfig();
        if (!apiKey) return res.status(503).json({ error: 'GEMINI_API_KEY não configurada na Vercel' });

        const prompt = buildClassifyPrompt({
            kind, label,
            secondaryLabel: cleanText(body.secondaryLabel, 180),
            currentCategoryID: ALLOWED_CATEGORY_IDS.has(currentCategoryID) ? currentCategoryID : '',
            categories
        });

        const geminiResponse = await fetch(`${endpoint}/models/${encodeURIComponent(model)}:generateContent`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: { temperature: 0.1, responseMimeType: 'application/json' }
            })
        });

        const responseText = await geminiResponse.text();
        if (!geminiResponse.ok) {
            return res.status(502).json({ error: 'Gemini recusou a classificação', status: geminiResponse.status });
        }

        let result;
        try {
            result = parseClassifyResult(extractGeminiText(JSON.parse(responseText)));
        } catch {
            return res.status(502).json({ error: 'Resposta Gemini inválida' });
        }

        const categoryID = cleanText(result.categoryID, 48);
        const confidence = Math.min(Math.max(Number(result.confidence) || 0, 0), 1);
        const reason = cleanText(result.reason, 160);

        if (!categories.some((c) => c.id === categoryID)) {
            return res.status(502).json({ error: 'Gemini retornou categoria inválida', categoryID });
        }

        return res.json({ categoryID, confidence, reason });
    } catch (err) {
        const statusCode = err.statusCode || 500;
        if (statusCode >= 500) console.error('[AI Classify Error]', err);
        return res.status(statusCode).json({
            error: err.statusCode ? err.message : 'Não foi possível classificar com IA'
        });
    }
}

// ── query (/api/ai/query) ───────────────────────────────────

const MAX_QUERY_LENGTH = 400;
const MAX_BREAKDOWN_ITEMS = 10;
const MAX_APP_ITEMS = 8;

function cleanNumber(value) {
    const n = Number(value);
    return Number.isFinite(n) && n >= 0 ? n : 0;
}

function formatDuration(seconds) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    if (h > 0) return m > 0 ? `${h}h${m}min` : `${h}h`;
    return `${m}min`;
}

function cleanContext(input = {}) {
    const breakdown = Array.isArray(input.categoryBreakdown) ? input.categoryBreakdown : [];
    const topApps = Array.isArray(input.topApps) ? input.topApps : [];
    return {
        date: cleanText(input.date, 20),
        totalTrackedTime: cleanNumber(input.totalTrackedTime),
        categoryBreakdown: breakdown
            .slice(0, MAX_BREAKDOWN_ITEMS)
            .map((i) => ({ label: cleanText(i?.label, 80), duration: cleanNumber(i?.duration) }))
            .filter((i) => i.label && i.duration > 0),
        topApps: topApps
            .slice(0, MAX_APP_ITEMS)
            .map((i) => ({ label: cleanText(i?.label, 80), duration: cleanNumber(i?.duration) }))
            .filter((i) => i.label && i.duration > 0),
        currentActivity: cleanText(input.currentActivity, 100) || null
    };
}

function buildQueryPrompt(query, context) {
    const breakdownLines = context.categoryBreakdown
        .map((i) => `- ${i.label}: ${formatDuration(i.duration)}`)
        .join('\n') || '- Sem dados de categoria ainda';
    const appLines = context.topApps
        .map((i) => `- ${i.label}: ${formatDuration(i.duration)}`)
        .join('\n') || '- Sem dados de apps ainda';
    const activityLine = context.currentActivity
        ? `Atividade ativa agora: ${context.currentActivity}`
        : 'Nenhuma atividade ativa no momento';

    return `Voce e o assistente de produtividade do Luum, um app de rastreamento de tempo para macOS.
Responda a pergunta do usuario com base nos dados de produtividade capturados pelo app.

Data: ${context.date || 'hoje'}
Tempo total rastreado: ${formatDuration(context.totalTrackedTime)}
${activityLine}

Distribuicao por categoria:
${breakdownLines}

Apps mais usados:
${appLines}

Pergunta: "${query}"

Instrucoes:
- Responda em portugues (pt-BR), de forma direta, util e concisa.
- Use os dados fornecidos como base. Nao invente informacoes ausentes.
- Se os dados forem insuficientes, diga brevemente o que falta.
- Maximo 3 paragrafos curtos. Prefira listas quando listar itens.
- Nao use markdown com asteriscos para negrito. Use linguagem natural.
- Nao repita a pergunta na resposta.`;
}

async function queryHandler(req, res) {
    addCors(req, res, { methods: 'POST, OPTIONS' });
    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'POST, OPTIONS' });
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const auth = await verifyFirebaseAndEntitlement(req, res);
        if (!auth) return;

        const body = jsonBody(req, 'JSON inválido');
        const query = cleanText(body.query, MAX_QUERY_LENGTH);
        if (!query) return res.status(400).json({ error: 'query obrigatória' });

        const context = cleanContext(body.context);
        const { apiKey, endpoint, model } = geminiConfig();
        if (!apiKey) return res.status(503).json({ error: 'GEMINI_API_KEY não configurada na Vercel' });

        const prompt = buildQueryPrompt(query, context);
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), EXTERNAL_REQUEST_TIMEOUT_MS);

        let geminiResponse;
        try {
            geminiResponse = await fetch(
                `${endpoint}/models/${encodeURIComponent(model)}:generateContent`,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
                    body: JSON.stringify({
                        contents: [{ parts: [{ text: prompt }] }],
                        generationConfig: { temperature: 0.5 }
                    }),
                    signal: controller.signal
                }
            );
        } finally {
            clearTimeout(timeout);
        }

        const responseText = await geminiResponse.text();
        if (!geminiResponse.ok) {
            return res.status(502).json({ error: 'Gemini recusou a consulta', status: geminiResponse.status });
        }

        let payload;
        try {
            payload = JSON.parse(responseText);
        } catch {
            return res.status(502).json({ error: 'Resposta Gemini inválida' });
        }

        const answer = extractGeminiText(payload).trim();
        if (!answer) return res.status(502).json({ error: 'Gemini retornou resposta vazia' });

        return res.json({ answer });
    } catch (err) {
        if (err.name === 'AbortError') {
            return res.status(504).json({ error: 'Gemini demorou demais para responder' });
        }
        if (!err.statusCode || err.statusCode >= 500) console.error('[AI Query Error]', err);
        return res.status(err.statusCode || 500).json({
            error: err.statusCode ? err.message : 'Não foi possível processar a consulta'
        });
    }
}

// ── Router ──────────────────────────────────────────────────

async function handler(req, res) {
    const action = req.query.action;
    if (action === 'classify') return classifyHandler(req, res);
    if (action === 'query') return queryHandler(req, res);
    return res.status(404).json({ error: `Ação de IA desconhecida: ${action}` });
}

module.exports = handler;
module.exports.handler = handler;
module.exports._private = {
    buildClassifyPrompt, cleanCategories, parseClassifyResult,
    buildQueryPrompt, cleanContext, extractGeminiText
};
