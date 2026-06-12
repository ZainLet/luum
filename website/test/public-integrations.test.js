const test = require('node:test');
const assert = require('node:assert/strict');

const settingsPath = require.resolve('../api/_integrationSettings');
const handlerPath = require.resolve('../api/public/integrations');

function response() {
    return {
        body: null,
        code: 200,
        headers: {},
        setHeader(name, value) {
            this.headers[name] = value;
        },
        status(code) {
            this.code = code;
            return this;
        },
        json(body) {
            this.body = body;
            return this;
        },
        end() {
            return this;
        }
    };
}

function installSettingsMock(values) {
    delete require.cache[settingsPath];
    delete require.cache[handlerPath];

    require.cache[settingsPath] = {
        id: settingsPath,
        filename: settingsPath,
        loaded: true,
        exports: {
            async getSetting(key) {
                return values[key] || '';
            }
        }
    };
}

test('public integrations endpoint exposes only non-secret connection bootstrap config', async () => {
    installSettingsMock({
        GOOGLE_CALENDAR_CLIENT_ID: 'google-client.apps.googleusercontent.com',
        OUTLOOK_CLIENT_ID: 'outlook-client-id',
        STRIPE_SECRET_KEY: 'sk_live_should_not_leak',
        NOTION_INTEGRATION_TOKEN: 'secret_should_not_leak'
    });

    const handler = require('../api/public/integrations');
    const res = response();

    await handler({
        method: 'GET',
        headers: { origin: 'https://luum-app.web.app' }
    }, res);

    assert.equal(res.code, 200);
    assert.equal(res.body.googleCalendar.configured, true);
    assert.equal(res.body.googleCalendar.clientID, 'google-client.apps.googleusercontent.com');
    assert.equal(res.body.outlookCalendar.configured, true);
    assert.equal(res.body.outlookCalendar.clientID, 'outlook-client-id');
    assert.equal(res.body.managedOAuth.googleCalendar, true);
    assert.equal(res.body.managedOAuth.outlookCalendar, false);
    assert.equal(JSON.stringify(res.body).includes('sk_live_should_not_leak'), false);
    assert.equal(JSON.stringify(res.body).includes('secret_should_not_leak'), false);
    assert.equal(res.headers['Cache-Control'], 'no-store, max-age=0');
});
