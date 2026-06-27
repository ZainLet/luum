'use strict';

const { oauthLog } = require('./_oauthLogger');

module.exports = async (req, res) => {
    const { code, error } = req.query;

    oauthLog('notion', 'callback_received', { hasCode: !!code, hasError: !!error, errorParam: error || null });

    if (error) {
        oauthLog('notion', 'callback_error', { reason: error });
        return res.redirect(`luum://notion?error=${encodeURIComponent(error)}`);
    }

    if (!code || typeof code !== 'string' || !code.trim()) {
        oauthLog('notion', 'callback_error', { reason: 'missing_code' });
        return res.redirect('luum://notion?error=missing_code');
    }

    const clientID = process.env.NOTION_CLIENT_ID;
    const clientSecret = process.env.NOTION_CLIENT_SECRET;
    if (!clientID || !clientSecret) {
        oauthLog('notion', 'token_exchange_error', { reason: 'server_not_configured' });
        return res.redirect('luum://notion?error=server_not_configured');
    }

    const host = req.headers.host || 'luum-app.vercel.app';
    const redirectURI = `https://${host}/api/integrations?action=notion-callback`;

    try {
        const credentials = Buffer.from(`${clientID}:${clientSecret}`).toString('base64');
        const tokenRes = await fetch('https://api.notion.com/v1/oauth/token', {
            method: 'POST',
            headers: {
                'Authorization': `Basic ${credentials}`,
                'Content-Type': 'application/json',
                'Notion-Version': '2022-06-28'
            },
            body: JSON.stringify({
                grant_type: 'authorization_code',
                code: code.trim(),
                redirect_uri: redirectURI
            })
        });

        const data = await tokenRes.json();

        if (!tokenRes.ok || !data.access_token) {
            oauthLog('notion', 'token_exchange_error', { status: tokenRes.status, errorCode: data.error || 'unknown' });
            const errMsg = data.error || 'token_exchange_failed';
            return res.redirect(`luum://notion?error=${encodeURIComponent(errMsg)}`);
        }

        oauthLog('notion', 'token_exchange_success', { workspaceId: data.workspace_id || null });

        const params = new URLSearchParams({
            access_token: data.access_token,
            workspace_name: data.workspace_name || 'Notion',
            workspace_id: data.workspace_id || ''
        });
        return res.redirect(`luum://notion?${params.toString()}`);
    } catch (err) {
        oauthLog('notion', 'network_error', { message: err.message });
        return res.redirect('luum://notion?error=server_error');
    }
};
