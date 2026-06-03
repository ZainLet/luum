const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');

function read(relativePath) {
    return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

test('site login links return to the account page by default', () => {
    const auth = read('auth.js');
    assert.match(auth, /login\.html\?redirect=account\.html/);

    for (const file of fs.readdirSync(root).filter((name) => name.endsWith('.html'))) {
        const html = read(file);
        assert.doesNotMatch(
            html,
            /href="login\.html" class="btn [^"]*js-auth-login"/,
            `${file} has a bare site login link`
        );
    }
});

test('desktop deeplink is opened only by the explicit app login route', () => {
    const login = read('login.html');

    assert.match(login, /return params\.get\('app'\) === 'mac';/);
    assert.doesNotMatch(login, /\|\| !getRedirectTarget\(\)/);
    assert.match(login, /function postLoginTarget\(\) \{\s*return getRedirectTarget\(\) \|\| 'account\.html';\s*\}/);
});
