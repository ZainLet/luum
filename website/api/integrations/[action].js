'use strict';

const clickupWebhook = require('./_clickup-webhook');
const linearAuth    = require('./_linear-auth');
const linearIssues  = require('./_linear-issues');
const notionAuth    = require('./_notion-auth');
const notionPages   = require('./_notion-pages');
const zapierAction  = require('./_zapier-action');
const zapierTrigger = require('./_zapier-trigger');

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
