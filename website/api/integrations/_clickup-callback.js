'use strict';

module.exports = async (req, res) => {
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const { code, error } = req.query;

    if (error || !code) {
        return res.redirect(`luum://clickup?error=${encodeURIComponent(error || 'code_missing')}`);
    }

    const clientID = process.env.CLICKUP_CLIENT_ID;
    const clientSecret = process.env.CLICKUP_CLIENT_SECRET;
    if (!clientID || !clientSecret) {
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
            const reason = encodeURIComponent(tokenData.error || 'token_exchange_failed');
            return res.redirect(`luum://clickup?error=${reason}`);
        }
    } catch {
        return res.redirect('luum://clickup?error=network_error');
    }

    const params = new URLSearchParams({ access_token: tokenData.access_token });
    return res.redirect(`luum://clickup?${params.toString()}`);
};
