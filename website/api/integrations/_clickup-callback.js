'use strict';

const { oauthLog } = require('./_oauthLogger');

module.exports = async (req, res) => {
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const { code, error } = req.query;

    oauthLog('clickup', 'callback_received', { hasCode: !!code, hasError: !!error, errorParam: error || null });

    if (error || !code) {
        const reason = error || 'code_missing';
        oauthLog('clickup', 'callback_error', { reason });
        return res.redirect(`luum://clickup?error=${encodeURIComponent(reason)}`);
    }

    const clientID = process.env.CLICKUP_CLIENT_ID;
    const clientSecret = process.env.CLICKUP_CLIENT_SECRET;
    if (!clientID || !clientSecret) {
        oauthLog('clickup', 'token_exchange_error', { reason: 'server_not_configured' });
        return res.redirect('luum://clickup?error=server_not_configured');
    }

    let tokenData;
    try {
        const response = await fetch('https://api.clickup.com/api/v2/oauth/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ client_id: clientID, client_secret: clientSecret, code }),
        });

        tokenData = await response.json();

        if (!response.ok || !tokenData.access_token) {
            oauthLog('clickup', 'token_exchange_error', { status: response.status, errorCode: tokenData.error || 'unknown' });
            const reason = encodeURIComponent(tokenData.error || 'token_exchange_failed');
            return res.redirect(`luum://clickup?error=${reason}`);
        }
    } catch (err) {
        oauthLog('clickup', 'network_error', { message: err.message });
        return res.redirect('luum://clickup?error=network_error');
    }

    oauthLog('clickup', 'token_exchange_success', {});

    const params = new URLSearchParams({ access_token: tokenData.access_token });
    return res.redirect(`luum://clickup?${params.toString()}`);
};
