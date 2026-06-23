const { addCors, handleOptions } = require('../_cors');
const { addNoStoreHeaders } = require('../_httpHeaders');
const { getSetting } = require('../_integrationSettings');

async function publicIntegrationsHandler(req, res) {
    addCors(req, res, { methods: 'GET, OPTIONS' });
    addNoStoreHeaders(res);

    if (req.method === 'OPTIONS') return handleOptions(req, res, { methods: 'GET, OPTIONS' });
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    const googleCalendarClientID = await getSetting('GOOGLE_CALENDAR_CLIENT_ID');
    const outlookClientID = await getSetting('OUTLOOK_CLIENT_ID');
    const notionClientID = await getSetting('NOTION_CLIENT_ID');

    return res.json({
        googleCalendar: {
            configured: Boolean(googleCalendarClientID),
            clientID: googleCalendarClientID || null
        },
        outlookCalendar: {
            configured: Boolean(outlookClientID),
            clientID: outlookClientID || null
        },
        managedOAuth: {
            googleCalendar: Boolean(googleCalendarClientID),
            outlookCalendar: false,
            notion: Boolean(notionClientID),
            clickUp: true,
            linear: true,
            zapier: true
        }
    });
}

module.exports = publicIntegrationsHandler;
module.exports.handler = publicIntegrationsHandler;
