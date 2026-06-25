'use strict';

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

module.exports = (req, res) => {
    const action = req.query.action;
    const handler = ROUTES[action];
    if (!handler) return res.status(404).json({ error: `Integração '${action}' não encontrada.` });
    return handler(req, res);
};
