'use strict';

const { admin, getFirestore } = require('./_firebaseAdmin');
const { applyCorsHeaders } = require('./_cors');
const { parseJsonBody } = require('./_jsonBody');
const { applySecurityHeaders } = require('./_httpHeaders');

const MAX_STACK_LENGTH = 4000;
const MAX_MESSAGE_LENGTH = 500;
const REDACT_PATTERN = /[A-Za-z0-9+/]{40,}={0,2}/g;

function sanitize(value, maxLen) {
    if (value == null) return null;
    return String(value).replace(REDACT_PATTERN, '[REDACTED]').substring(0, maxLen);
}

module.exports = async (req, res) => {
    applySecurityHeaders(res);
    if (applyCorsHeaders(req, res)) return;
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    const authHeader = req.headers.authorization || '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!idToken) return res.status(401).json({ error: 'Login necessário.' });

    let uid;
    try {
        const decoded = await admin.auth().verifyIdToken(idToken);
        uid = decoded.uid;
    } catch {
        return res.status(401).json({ error: 'Token inválido.' });
    }

    const body = await parseJsonBody(req);
    const { appVersion, build, macOSVersion, errorType, stack, signal, exceptionName, message } = body || {};

    if (!appVersion || !errorType) {
        return res.status(400).json({ error: 'appVersion e errorType são obrigatórios.' });
    }

    const db = getFirestore();
    const timestamp = Date.now();

    await db
        .collection('crashReports')
        .doc(uid)
        .collection('reports')
        .doc(String(timestamp))
        .set({
            uid,
            appVersion: String(appVersion).substring(0, 20),
            build: String(build || '').substring(0, 20),
            macOSVersion: String(macOSVersion || '').substring(0, 80),
            errorType: String(errorType).substring(0, 100),
            exceptionName: exceptionName ? String(exceptionName).substring(0, 100) : null,
            stack: sanitize(stack, MAX_STACK_LENGTH),
            signal: signal ? String(signal).substring(0, 20) : null,
            message: sanitize(message, MAX_MESSAGE_LENGTH),
            status: 'novo',
            reportedAt: new Date().toISOString(),
            timestamp,
        });

    return res.status(200).json({ ok: true, reportId: String(timestamp) });
};
