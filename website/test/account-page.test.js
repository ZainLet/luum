const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const accountHTML = fs.readFileSync(path.join(__dirname, '..', 'account.html'), 'utf8');

test('account page renders plan dates from the official entitlement contract first', () => {
    assert.match(
        accountHTML,
        /const end = timestampMillis\(entitlement\.expiresAt\) \|\| timestampMillis\(sub\.currentPeriodEnd\);/
    );
    assert.match(
        accountHTML,
        /const trialEnd =\s*timestampMillis\(entitlement\.trialEndsAt\) \|\|\s*timestampMillis\(entitlement\.expiresAt\) \|\|\s*timestampMillis\(sub\.trialEndsAt\)/m
    );
});

test('account page validates the account document before reading Firestore metadata', () => {
    assert.match(accountHTML, /fetch\(luumApiUrl\('\/api\/auth\/upsert-user'\)/);
    assert.match(accountHTML, /fetch\(luumApiUrl\('\/api\/auth\/status'\)/);
    assert.match(accountHTML, /renderAccount\(user, data, entitlement\)/);
});
