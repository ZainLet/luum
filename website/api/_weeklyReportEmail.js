const DEFAULT_GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta';
const DEFAULT_GEMINI_MODEL = 'gemini-2.5-flash';
const MAX_BREAKDOWN_ITEMS = 10;
const MAX_HIGHLIGHTS = 8;
const EXTERNAL_REQUEST_TIMEOUT_MS = 15_000;

function cleanText(value, maxLength = 180) {
    return String(value || '')
        .trim()
        .replace(/\s+/g, ' ')
        .slice(0, maxLength);
}

function cleanNumber(value, fallback = 0) {
    const number = Number(value);
    return Number.isFinite(number) && number >= 0 ? number : fallback;
}

function cleanEmail(value) {
    const email = String(value || '').trim().toLowerCase();
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : '';
}

function cleanBreakdown(items) {
    return (Array.isArray(items) ? items : [])
        .slice(0, MAX_BREAKDOWN_ITEMS)
        .map((item) => ({
            label: cleanText(item && item.label, 100),
            duration: cleanNumber(item && item.duration)
        }))
        .filter((item) => item.label && item.duration > 0);
}

function cleanReportPayload(input = {}) {
    return {
        startDate: cleanText(input.startDate, 40),
        endDate: cleanText(input.endDate, 40),
        totalTrackedTime: cleanNumber(input.totalTrackedTime),
        averageDailyTrackedTime: cleanNumber(input.averageDailyTrackedTime),
        contextSwitches: Math.round(cleanNumber(input.contextSwitches)),
        focusTime: cleanNumber(input.focusTime),
        distractionTime: cleanNumber(input.distractionTime),
        topCategories: cleanBreakdown(input.topCategories),
        topApps: cleanBreakdown(input.topApps),
        topSites: cleanBreakdown(input.topSites),
        highlights: (Array.isArray(input.highlights) ? input.highlights : [])
            .slice(0, MAX_HIGHLIGHTS)
            .map((item) => cleanText(item, 180))
            .filter(Boolean)
    };
}

function minutes(seconds) {
    return Math.round(cleanNumber(seconds) / 60);
}

function buildReportPrompt({ report, accountEmail }) {
    return `Voce e o analista semanal do Luum, um app de produtividade.
Gere um resumo executivo em portugues para enviar por email ao usuario ${accountEmail || 'Luum'}.

Dados sanitizados:
${JSON.stringify({
        semana: { inicio: report.startDate, fim: report.endDate },
        minutosTotais: minutes(report.totalTrackedTime),
        mediaDiariaMinutos: minutes(report.averageDailyTrackedTime),
        minutosFoco: minutes(report.focusTime),
        minutosDistração: minutes(report.distractionTime),
        trocasDeContexto: report.contextSwitches,
        topCategorias: report.topCategories.map((item) => ({ label: item.label, minutos: minutes(item.duration) })),
        topApps: report.topApps.map((item) => ({ label: item.label, minutos: minutes(item.duration) })),
        topSites: report.topSites.map((item) => ({ label: item.label, minutos: minutes(item.duration) })),
        destaques: report.highlights
    })}

Responda apenas JSON valido neste formato:
{"title":"Resumo semanal Luum","summary":"2 frases curtas.","highlights":["ate 4 bullets"],"recommendations":["ate 3 recomendacoes praticas"]}`;
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

function parseNarrative(text) {
    const raw = String(text || '').trim();
    const match = raw.match(/\{[\s\S]*\}/);
    const parsed = JSON.parse(match ? match[0] : raw);
    return {
        title: cleanText(parsed.title, 90) || 'Resumo semanal Luum',
        summary: cleanText(parsed.summary, 600),
        highlights: (Array.isArray(parsed.highlights) ? parsed.highlights : [])
            .slice(0, 4)
            .map((item) => cleanText(item, 180))
            .filter(Boolean),
        recommendations: (Array.isArray(parsed.recommendations) ? parsed.recommendations : [])
            .slice(0, 3)
            .map((item) => cleanText(item, 180))
            .filter(Boolean)
    };
}

async function fetchWithTimeout(fetchImpl, url, options = {}) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), EXTERNAL_REQUEST_TIMEOUT_MS);
    try {
        return await fetchImpl(url, {
            ...options,
            signal: controller.signal
        });
    } catch (error) {
        if (error?.name === 'AbortError') {
            const timeoutError = new Error('Serviço externo demorou demais para responder');
            timeoutError.statusCode = 504;
            throw timeoutError;
        }
        throw error;
    } finally {
        clearTimeout(timeout);
    }
}

async function generateNarrative({ report, accountEmail, fetchImpl = fetch }) {
    const apiKey = cleanText(process.env.GEMINI_API_KEY, 4096);
    if (!apiKey) {
        const error = new Error('GEMINI_API_KEY não configurada na Vercel');
        error.statusCode = 500;
        throw error;
    }

    const endpoint = cleanText(process.env.GEMINI_ENDPOINT || DEFAULT_GEMINI_ENDPOINT, 512).replace(/\/+$/, '');
    const model = cleanText(process.env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL, 120);
    const geminiResponse = await fetchWithTimeout(fetchImpl, `${endpoint}/models/${encodeURIComponent(model)}:generateContent`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey
        },
        body: JSON.stringify({
            contents: [{ parts: [{ text: buildReportPrompt({ report, accountEmail }) }] }],
            generationConfig: {
                temperature: 0.2,
                responseMimeType: 'application/json'
            }
        })
    });

    const responseText = await geminiResponse.text();
    if (!geminiResponse.ok) {
        const error = new Error('Gemini recusou o relatório');
        error.statusCode = 502;
        throw error;
    }

    try {
        return parseNarrative(extractGeminiText(JSON.parse(responseText)));
    } catch {
        const error = new Error('Resposta Gemini inválida');
        error.statusCode = 502;
        throw error;
    }
}

function pdfEscape(value) {
    return String(value || '').replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
}

function wrapLine(value, maxLength = 88) {
    const words = String(value || '').split(/\s+/).filter(Boolean);
    const lines = [];
    let current = '';
    for (const word of words) {
        const next = current ? `${current} ${word}` : word;
        if (next.length > maxLength && current) {
            lines.push(current);
            current = word;
        } else {
            current = next;
        }
    }
    if (current) lines.push(current);
    return lines.length ? lines : [''];
}

function makePDFTextLines({ report, narrative }) {
    const lines = [
        narrative.title || 'Resumo semanal Luum',
        `Semana: ${report.startDate || '-'} a ${report.endDate || '-'}`,
        '',
        narrative.summary || 'Resumo semanal gerado pelo Luum.',
        '',
        `Tempo total: ${minutes(report.totalTrackedTime)} min`,
        `Média diária: ${minutes(report.averageDailyTrackedTime)} min`,
        `Foco: ${minutes(report.focusTime)} min`,
        `Distrações: ${minutes(report.distractionTime)} min`,
        `Trocas de contexto: ${report.contextSwitches}`,
        '',
        'Destaques'
    ];

    for (const item of narrative.highlights.length ? narrative.highlights : report.highlights) {
        lines.push(`- ${item}`);
    }
    lines.push('', 'Recomendações');
    for (const item of narrative.recommendations.length ? narrative.recommendations : ['Revise suas maiores categorias e ajuste metas para a próxima semana.']) {
        lines.push(`- ${item}`);
    }
    lines.push('', 'Top categorias');
    for (const item of report.topCategories.slice(0, 6)) {
        lines.push(`- ${item.label}: ${minutes(item.duration)} min`);
    }
    return lines.flatMap((line) => wrapLine(line));
}

function createSimplePDF({ report, narrative }) {
    const textLines = makePDFTextLines({ report, narrative }).slice(0, 46);
    const content = [
        'BT',
        '/F1 20 Tf',
        '54 760 Td',
        `(${pdfEscape(textLines.shift() || 'Resumo semanal Luum')}) Tj`,
        '/F1 11 Tf',
        '0 -28 Td',
        ...textLines.map((line) => `(${pdfEscape(line)}) Tj 0 -16 Td`),
        'ET'
    ].join('\n');

    const objects = [
        '<< /Type /Catalog /Pages 2 0 R >>',
        '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        `<< /Length ${Buffer.byteLength(content, 'utf8')} >>\nstream\n${content}\nendstream`
    ];

    let pdf = '%PDF-1.4\n';
    const offsets = [0];
    objects.forEach((object, index) => {
        offsets.push(Buffer.byteLength(pdf, 'utf8'));
        pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
    });
    const xrefOffset = Buffer.byteLength(pdf, 'utf8');
    pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
    for (let index = 1; index < offsets.length; index += 1) {
        pdf += `${String(offsets[index]).padStart(10, '0')} 00000 n \n`;
    }
    pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;
    return Buffer.from(pdf, 'utf8');
}

async function sendReportEmail({ to, subject, html, pdfBuffer, fileName, fetchImpl = fetch }) {
    const apiKey = cleanText(process.env.RESEND_API_KEY, 4096);
    const from = cleanText(process.env.REPORT_EMAIL_FROM || process.env.RESEND_FROM_EMAIL, 180);
    if (!apiKey || !from) {
        const error = new Error('RESEND_API_KEY e REPORT_EMAIL_FROM precisam estar configurados na Vercel');
        error.statusCode = 500;
        throw error;
    }

    const response = await fetchWithTimeout(fetchImpl, 'https://api.resend.com/emails', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            from,
            to: [to],
            subject,
            html,
            attachments: [{
                filename: fileName,
                content: pdfBuffer.toString('base64')
            }]
        })
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
        const error = new Error(data.message || 'Provedor de email recusou o envio');
        error.statusCode = 502;
        throw error;
    }
    return data;
}

function escapeHTML(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function reportHTML({ narrative, report }) {
    const list = (items) => items.map((item) => `<li>${escapeHTML(cleanText(item, 180))}</li>`).join('');
    return `
        <h1>${escapeHTML(cleanText(narrative.title, 90)) || 'Resumo semanal Luum'}</h1>
        <p>${escapeHTML(cleanText(narrative.summary, 600))}</p>
        <p><strong>Semana:</strong> ${escapeHTML(cleanText(report.startDate, 40))} a ${escapeHTML(cleanText(report.endDate, 40))}</p>
        <h2>Destaques</h2>
        <ul>${list(narrative.highlights)}</ul>
        <h2>Recomendações</h2>
        <ul>${list(narrative.recommendations)}</ul>
    `;
}

module.exports = {
    buildReportPrompt,
    cleanEmail,
    cleanReportPayload,
    createSimplePDF,
    escapeHTML,
    generateNarrative,
    parseNarrative,
    reportHTML,
    sendReportEmail
};
