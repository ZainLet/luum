'use strict';

module.exports = async (req, res) => {
    return res.status(403).json({ error: 'Integração Notion não configurada. Configure no admin.' });
};
