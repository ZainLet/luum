const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const packageJSON = JSON.parse(
    fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8')
);

test('website API runtime stays compatible with firebase-admin 14', () => {
    assert.match(packageJSON.dependencies['firebase-admin'], /\^14\./);
    assert.match(packageJSON.engines.node, />=22/);
});

test('security policy documents Luum alpha production boundaries', () => {
    const securityPolicy = fs.readFileSync(path.join(__dirname, '..', '..', 'SECURITY.md'), 'utf8');

    assert.doesNotMatch(securityPolicy, /Use this section/i);
    assert.match(securityPolicy, /v0\.0\.x-alpha/);
    assert.match(securityPolicy, /https:\/\/luum-app\.vercel\.app/);
    assert.match(securityPolicy, /FIREBASE_SERVICE_ACCOUNT_JSON/);
    assert.match(securityPolicy, /STRIPE_SECRET_KEY/);
    assert.match(securityPolicy, /GEMINI_API_KEY/);
    assert.match(securityPolicy, /com\.luum\.apple/);
});
