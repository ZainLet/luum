const test = require('node:test');
const assert = require('node:assert/strict');
const { addCors, allowedOrigin, handleOptions, normalizedOrigin } = require('../api/_cors');

function response() {
    const headers = {};
    return {
        body: null,
        code: null,
        ended: false,
        headers,
        setHeader(name, value) {
            headers[name] = value;
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
            this.ended = true;
            return this;
        }
    };
}

test('normalizes and permits only official Luum browser origins', () => {
    assert.equal(normalizedOrigin('https://luum-app.web.app/login.html'), 'https://luum-app.web.app');
    assert.equal(allowedOrigin('https://luum-app.web.app'), 'https://luum-app.web.app');
    assert.equal(allowedOrigin('https://luum-app.firebaseapp.com'), 'https://luum-app.firebaseapp.com');
    assert.equal(allowedOrigin('https://luum-app.vercel.app'), 'https://luum-app.vercel.app');
    assert.equal(allowedOrigin('https://example.com'), '');
    assert.equal(allowedOrigin('not a url'), '');
});

test('adds CORS headers for official Firebase Hosting origin', () => {
    const res = response();
    const ok = addCors(
        { headers: { origin: 'https://luum-app.web.app' } },
        res,
        { methods: 'POST, OPTIONS' }
    );

    assert.equal(ok, true);
    assert.equal(res.headers['Access-Control-Allow-Origin'], 'https://luum-app.web.app');
    assert.equal(res.headers['Access-Control-Allow-Headers'], 'Authorization, Content-Type');
    assert.equal(res.headers['Access-Control-Allow-Methods'], 'POST, OPTIONS');
    assert.equal(res.headers.Vary, 'Origin');
});

test('does not expose CORS responses to unknown browser origins', () => {
    const res = response();
    const ok = addCors(
        { headers: { origin: 'https://attacker.example' } },
        res,
        { methods: 'GET, OPTIONS' }
    );

    assert.equal(ok, false);
    assert.equal(res.headers['Access-Control-Allow-Origin'], undefined);
    assert.equal(res.headers['Access-Control-Allow-Methods'], 'GET, OPTIONS');
});

test('rejects preflight requests from unknown origins', () => {
    const res = response();
    handleOptions(
        { headers: { origin: 'https://attacker.example' } },
        res,
        { methods: 'POST, OPTIONS' }
    );

    assert.equal(res.code, 403);
    assert.deepEqual(res.body, { error: 'Origin não permitida' });
});
