const { admin, getFirestore } = require('../_firebaseAdmin');
const { addCors, handleOptions } = require('../_cors');
const { entitlementForUser, includesFeature } = require('../_entitlements');
const { jsonBody } = require('../_jsonBody');

const DEFAULT_GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta';
const DEFAULT_GEMINI_MODEL = 'gemini-2.5-flash';
const MAX_QUERY_LENGTH = 400;
const MAX_BREAKDOWN_ITEMS = 10;
const MAX_APP_ITEMS = 8;
const EXTERNAL_REQUEST_TIMEOUT_MS = 20_000;

function cleanText(value, maxLength = 180) {
    return String(value || '')
        .trim()
        .replace(/\s+/g, ' ')
        .slice(0, maxLength);
}

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
            .map((item) => ({ label: cleanText(item?.label, 80), duration: cleanNumber(item?.duration) }))
            .filter((i) => i.label && i.duration > 0),
        topApps: topApps
            .slice(0, MAX_APP_ITEMS)
            .map((item) => ({ label: cleanText(item?.label, 80), duration: cleanNumber(item?.duration) }))
            .filter((i) => i.label && i.duration > 0),
        currentActivity: cleanText(input.currentActivity, 100) || null
    };
}

function buildPrompt(query, context) {
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

function extractGeminiText(payload) {
    const candidates = Array.isArray(payload?.candidates) ? payload.candidates : [];
    for (const candidate of candidates) {
        const parts = Array.isArray(candidate?.content?.parts) ? candidate.content.parts : [];
        const text = parts
            .map((p) => p?.text)
            .filter(Boolean)
            .join('\n')
            .trim();
        if (text) return text;
    }
    return '';
}

async function queryHandler(req, res) {
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
            return res.status(403).json({ error: 'Plano sem acesso ao assistente de IA', entitlement });
        }

        const body = jsonBody(req, 'JSON inválido');
        const query = cleanText(body.query, MAX_QUERY_LENGTH);
        if (!query) return res.status(400).json({ error: 'query obrigatória' });

        const context = cleanContext(body.context);

        const apiKey = cleanText(process.env.GEMINI_API_KEY, 4096);
        if (!apiKey) return res.status(500).json({ error: 'GEMINI_API_KEY não configurada na Vercel' });

        const prompt = buildPrompt(query, context);
        const endpoint = cleanText(
            process.env.GEMINI_ENDPOINT || DEFAULT_GEMINI_ENDPOINT,
            512
        ).replace(/\/+$/, '');
        const model = cleanText(process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL, 120);

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), EXTERNAL_REQUEST_TIMEOUT_MS);

        let geminiResponse;
        try {
            geminiResponse = await fetch(
                `${endpoint}/models/${encodeURIComponent(model)}:generateContent`,
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'x-goog-api-key': apiKey
                    },
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
            return res.status(502).json({
                error: 'Gemini recusou a consulta',
                status: geminiResponse.status
            });
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
        if (!err.statusCode || err.statusCode >= 500) {
            console.error('[AI Query Error]', err);
        }
        return res.status(err.statusCode || 500).json({
            error: err.statusCode ? err.message : 'Não foi possível processar a consulta'
        });
    }
}

module.exports = queryHandler;
module.exports.handler = queryHandler;
module.exports._private = { buildPrompt, cleanContext, extractGeminiText };
