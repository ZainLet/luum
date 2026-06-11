const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const adminHTML = fs.readFileSync(path.join(__dirname, '..', 'admin.html'), 'utf8');

test('admin page makes the effective app entitlement visible', () => {
    assert.match(adminHTML, /Plano efetivo lido pelo app/);
    assert.match(adminHTML, /Plano raiz Firestore/);
    assert.match(adminHTML, /Plano legado onboarding/);
    assert.match(adminHTML, /confira se o e-mail acima aparece no painel lateral/);
});

test('admin save message identifies the account that was changed', () => {
    assert.match(adminHTML, /Acesso atualizado para/);
    assert.match(adminHTML, /confira esta mesma conta/);
});
