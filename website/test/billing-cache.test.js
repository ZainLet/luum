const test = require('node:test');
const assert = require('node:assert/strict');

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

function assertNoStore(res) {
    assert.equal(res.headers['Cache-Control'], 'no-store, max-age=0');
    assert.equal(res.headers.Pragma, 'no-cache');
    assert.equal(res.headers.Expires, '0');
}

test('checkout responses are never cacheable', async () => {
    const handler = require('../api/checkout');
    const res = response();

    await handler({
        method: 'POST',
        headers: { origin: 'https://luum-app.web.app' },
        body: { plan: 'invalid-plan', uid: 'firebase-user' }
    }, res);

    assert.equal(res.code, 400);
    assertNoStore(res);
});

test('subscription cancellation responses are never cacheable', async () => {
    const handler = require('../api/cancel-subscription');
    const res = response();

    await handler({
        method: 'POST',
        headers: { origin: 'https://luum-app.web.app' },
        body: {}
    }, res);

    assert.equal(res.code, 401);
    assertNoStore(res);
});
