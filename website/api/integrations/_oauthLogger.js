'use strict';

function oauthLog(integration, event, details = {}) {
    console.log(JSON.stringify({
        ts: new Date().toISOString(),
        service: 'oauth',
        integration,
        event,
        ...details,
    }));
}

module.exports = { oauthLog };
