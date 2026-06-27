'use strict';

const { oauthLog } = require('./_oauthLogger');

module.exports = async (req, res) => {
    const { code, error } = req.query;

    oauthLog('outlook', 'callback_received', { hasCode: !!code, hasError: !!error, errorParam: error || null });

    if (error) {
        oauthLog('outlook', 'callback_error', { reason: error });
        return res.redirect(`luum://outlook?error=${encodeURIComponent(error)}`);
    }

    if (!code || typeof code !== 'string' || !code.trim()) {
        oauthLog('outlook', 'callback_error', { reason: 'missing_code' });
        return res.redirect('luum://outlook?error=missing_code');
    }

    const clientID = process.env.OUTLOOK_CLIENT_ID;
    const clientSecret = process.env.OUTLOOK_CLIENT_SECRET;
    if (!clientID || !clientSecret) {
        oauthLog('outlook', 'token_exchange_error', { reason: 'server_not_configured' });
        return res.redirect('luum://outlook?error=server_not_configured');
    }

    const host = req.headers.host || 'luum-app.vercel.app';
    const redirectURI = `https://${host}/api/integrations?action=outlook-callback`;

    try {
        const body = new URLSearchParams({
            grant_type: 'authorization_code',
            code: code.trim(),
            client_id: clientID,
            client_secret: clientSecret,
            redirect_uri: redirectURI,
            scope: 'offline_access openid profile Calendars.Read Mail.ReadBasic'
        });

        const tokenRes = await fetch('https://login.microsoftonline.com/common/oauth2/v2.0/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: body.toString()
        });

        const data = await tokenRes.json();

        if (!tokenRes.ok || !data.access_token) {
            oauthLog('outlook', 'token_exchange_error', { status: tokenRes.status, errorCode: data.error || 'unknown' });
            const errMsg = data.error || 'token_exchange_failed';
            return res.redirect(`luum://outlook?error=${encodeURIComponent(errMsg)}`);
        }

        oauthLog('outlook', 'token_exchange_success', { hasRefreshToken: !!data.refresh_token, expiresIn: data.expires_in || 3600 });

        const params = new URLSearchParams({
            access_token: data.access_token,
            refresh_token: data.refresh_token || '',
            expires_in: String(data.expires_in || 3600)
        });
        return res.redirect(`luum://outlook?${params.toString()}`);
    } catch (err) {
        oauthLog('outlook', 'network_error', { message: err.message });
        return res.redirect('luum://outlook?error=server_error');
    }
};
