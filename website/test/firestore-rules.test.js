const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.join(__dirname, '..', '..');

function read(relativePath) {
    return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

test('root and website Firestore rules stay locked to backend-only writes', () => {
    const rootRules = read('firestore.rules');
    const websiteRules = read('website/firestore.rules');

    assert.equal(rootRules, websiteRules);
    assert.match(rootRules, /match \/users\/\{userId\}/);
    assert.match(rootRules, /allow read: if request\.auth != null && request\.auth\.uid == userId;/);
    assert.match(rootRules, /allow write: if false;/);
    assert.match(rootRules, /match \/backups\/\{backupId\}/);
    assert.match(rootRules, /match \/config\/\{document=\*\*\}/);
    assert.doesNotMatch(rootRules, /allow read, write: if request\.auth != null/);
    assert.doesNotMatch(rootRules, /match \/usuarios/);
});

test('root Firebase project points at the production Luum app', () => {
    const firebaseRC = JSON.parse(read('.firebaserc'));
    assert.equal(firebaseRC.projects.default, 'luum-app');
});
