const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
    API_BASE_URL,
    OFFICIAL_ORIGINS,
    PUBLIC_SITE_URL,
    officialSiteURL,
    webhookURL
} = require('../api/_publicConfig');
const { allowedOrigin } = require('../api/_cors');
const { checkoutSiteURL } = require('../api/_checkoutSecurity');

test('keeps public site and API URLs centralized', () => {
    assert.equal(PUBLIC_SITE_URL, 'https://luum-app.web.app');
    assert.equal(API_BASE_URL, 'https://luum-app.vercel.app');
    assert.equal(webhookURL(), 'https://luum-app.vercel.app/api/webhook');
    assert.deepEqual(OFFICIAL_ORIGINS, [
        'https://luum-app.web.app',
        'https://luum-app.firebaseapp.com',
        'https://luum-app.vercel.app'
    ]);
});

test('uses centralized official site URL for checkout redirects', () => {
    assert.equal(officialSiteURL(''), PUBLIC_SITE_URL);
    assert.equal(checkoutSiteURL('https://luum-app.web.app/'), PUBLIC_SITE_URL);
    assert.equal(checkoutSiteURL('https://example.com'), null);
});

test('uses centralized origins for CORS allowlist', () => {
    assert.equal(allowedOrigin(PUBLIC_SITE_URL), PUBLIC_SITE_URL);
    assert.equal(allowedOrigin(API_BASE_URL), API_BASE_URL);
    assert.equal(allowedOrigin('https://example.com'), '');
});

test('public Firebase config documents Vercel as the only desktop backend', () => {
    const firebaseConfig = fs.readFileSync(path.join(__dirname, '..', 'firebase-config.js'), 'utf8');

    assert.match(firebaseConfig, /backend oficial fica na Vercel/);
    assert.match(firebaseConfig, /api\/auth\/status/);
    assert.match(firebaseConfig, /Nunca coloque chave privada Firebase no app macOS/);
    assert.doesNotMatch(firebaseConfig, /Admin SDK diretamente/);
});
