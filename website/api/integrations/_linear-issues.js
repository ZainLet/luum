'use strict';

module.exports = async (req, res) => {
    return res.status(403).json({ error: 'Integração Linear não autenticada.' });
};
