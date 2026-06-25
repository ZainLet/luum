'use strict';

const crypto = require('crypto');

module.exports = async (req, res) => {
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const { code, error, state } = req.query;

    const clientSecret = process.env.LINEAR_CLIENT_SECRET;
    if (clientSecret && state) {
        const dotIndex = state.lastIndexOf('.');
        if (dotIndex === -1) return res.redirect('luum://linear?error=invalid_state');
        const stateVal = state.substring(0, dotIndex);
        const stateHmac = state.substring(dotIndex + 1);
        const expected = crypto.createHmac('sha256', clientSecret).update(stateVal).digest('hex');
        let valid = false;
        try { valid = crypto.timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(stateHmac, 'hex')); } catch { /* length mismatch */ }
        if (!valid) return res.redirect('luum://linear?error=invalid_state');
    } else if (clientSecret && !state) {
        return res.redirect('luum://linear?error=missing_state');
    }

    if (error || !code) {
        const reason = encodeURIComponent(error || 'code_missing');
        return res.redirect(`luum://linear?error=${reason}`);
    }

    const clientID = process.env.LINEAR_CLIENT_ID;
    if (!clientID || !clientSecret) {
        return res.redirect('luum://linear?error=server_not_configured');
    }

    const redirectURI = `https://${req.headers.host}/api/integrations?action=linear-callback`;

    let tokenResponse;
    try {
        const body = new URLSearchParams({
            code,
            redirect_uri: redirectURI,
            client_id: clientID,
            client_secret: clientSecret,
            grant_type: 'authorization_code',
        });

        const response = await fetch('https://api.linear.app/oauth/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: body.toString(),
        });

        tokenResponse = await response.json();

        if (!response.ok || !tokenResponse.access_token) {
            const reason = encodeURIComponent(tokenResponse.error || 'token_exchange_failed');
            return res.redirect(`luum://linear?error=${reason}`);
        }
    } catch {
        return res.redirect('luum://linear?error=network_error');
    }

    const params = new URLSearchParams({
        access_token: tokenResponse.access_token,
        token_type: tokenResponse.token_type || 'Bearer',
        scope: tokenResponse.scope || '',
    });

    return res.redirect(`luum://linear?${params.toString()}`);
};
