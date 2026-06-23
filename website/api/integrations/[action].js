'use strict';

const clickupWebhook = require('./clickup-webhook');
const linearAuth    = require('./linear-auth');
const linearIssues  = require('./linear-issues');
const notionAuth    = require('./notion-auth');
const notionPages   = require('./notion-pages');
const zapierAction  = require('./zapier-action');
const zapierTrigger = require('./zapier-trigger');

const ROUTES = {
    'clickup-webhook': clickupWebhook,
    'linear-auth':     linearAuth,
    'linear-issues':   linearIssues,
    'notion-auth':     notionAuth,
    'notion-pages':    notionPages,
    'zapier-action':   zapierAction,
    'zapier-trigger':  zapierTrigger,
};

module.exports = (req, res) => {
    const action = req.query.action;
    const handler = ROUTES[action];
    if (!handler) return res.status(404).json({ error: `Integração '${action}' não encontrada.` });
    return handler(req, res);
};
