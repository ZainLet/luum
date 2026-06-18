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

    const { admin } = require('../api/_firebaseAdmin');
    assert.equal(typeof admin.auth, 'function');
    assert.equal(typeof admin.firestore, 'function');
    assert.equal(typeof admin.firestore.FieldValue.serverTimestamp, 'function');
    assert.equal(typeof admin.firestore.Timestamp.fromMillis, 'function');
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

test('billing docs match the default one-seat checkout contract', () => {
    const checklist = fs.readFileSync(path.join(__dirname, '..', '..', 'docs', 'CHECKLIST_INTEGRACOES_EXTERNAS.md'), 'utf8');
    const pending = fs.readFileSync(path.join(__dirname, '..', '..', 'docs', 'INTEGRACOES_PENDENTES.md'), 'utf8');

    assert.match(checklist, /checkout aceita 1 assento em todos os planos/i);
    assert.match(checklist, /STRIPE_MIN_SEATS_EQUIPES/);
    assert.match(checklist, /STRIPE_MIN_SEATS_NEGOCIOS/);
    assert.doesNotMatch(checklist, /Equipes:.*minimo 2 usuarios/i);
    assert.doesNotMatch(checklist, /Negocios:.*minimo 5 usuarios/i);
    assert.match(pending, /Por padrão, todos os planos aceitam 1 assento/i);
});
