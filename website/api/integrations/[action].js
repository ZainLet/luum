'use strict';

const { checkRateLimit } = require('../_rateLimit');
const clickupAuth    = require('./_clickup-auth');
const clickupCallback = require('./_clickup-callback');
const clickupTasks   = require('./_clickup-tasks');
const clickupWebhook = require('./_clickup-webhook');
const linearAuth     = require('./_linear-auth');
const linearCallback = require('./_linear-callback');
const linearIssues   = require('./_linear-issues');
const notionAuth     = require('./_notion-auth');
const notionCallback = require('./_notion-callback');
const notionPages    = require('./_notion-pages');
const outlookAuth    = require('./_outlook-auth');
const outlookCallback = require('./_outlook-callback');
const outlookRefresh = require('./_outlook-refresh');
const zapierAction       = require('./_zapier-action');
const zapierTrigger      = require('./_zapier-trigger');
const zapierWebhookConfig = require('./_zapier-webhook-config');

const ROUTES = {
    'clickup-auth':     clickupAuth,
    'clickup-callback': clickupCallback,
    'clickup-tasks':    clickupTasks,
    'clickup-webhook':  clickupWebhook,
    'linear-auth':     linearAuth,
    'linear-callback': linearCallback,
    'linear-issues':   linearIssues,
    'notion-auth':     notionAuth,
    'notion-callback': notionCallback,
    'notion-pages':    notionPages,
    'outlook-auth':    outlookAuth,
    'outlook-callback': outlookCallback,
    'outlook-refresh': outlookRefresh,
    'zapier-action':        zapierAction,
    'zapier-trigger':       zapierTrigger,
    'zapier-webhook-config': zapierWebhookConfig,
};

// Callbacks exchange OAuth codes — tighter limit to prevent code brute-forcing
const CALLBACK_ACTIONS = new Set(['clickup-callback', 'linear-callback', 'notion-callback', 'outlook-callback']);
// Auth endpoints generate OAuth URLs — moderate limit
const AUTH_ACTIONS = new Set(['clickup-auth', 'linear-auth', 'notion-auth', 'outlook-auth']);

function rateLimitForAction(req, action) {
    if (CALLBACK_ACTIONS.has(action)) {
        return checkRateLimit(req, { windowMs: 60_000, max: 10, key: `integration:${action}` });
    }
    if (AUTH_ACTIONS.has(action)) {
        return checkRateLimit(req, { windowMs: 60_000, max: 20, key: `integration:${action}` });
    }
    return { limited: false };
}

module.exports = (req, res) => {
    const action = req.query.action;
    const handler = ROUTES[action];
    if (!handler) return res.status(404).json({ error: `Integração '${action}' não encontrada.` });

    const rl = rateLimitForAction(req, action);
    if (rl.limited) {
        res.setHeader('Retry-After', String(rl.retryAfter));
        return res.status(429).json({ error: 'Muitas requisições. Tente novamente em breve.' });
    }

    return handler(req, res);
};
