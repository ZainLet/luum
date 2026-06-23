'use strict';

module.exports = async (req, res) => {
    const secret = process.env.CLICKUP_WEBHOOK_SECRET;
    if (!secret) {
        return res.status(503).json({ error: 'ClickUp webhook não configurado' });
    }
    return res.status(200).json({ ok: true });
};
