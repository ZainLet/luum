const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');

function read(relativePath) {
    return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

test('site auth links return to the account page by default', () => {
    const auth = read('auth.js');
    assert.match(auth, /login\.html\?redirect=account\.html/);
    assert.match(auth, /cadastro\.html\?redirect=account\.html/);

    for (const file of fs.readdirSync(root).filter((name) => name.endsWith('.html'))) {
        const html = read(file);
        assert.doesNotMatch(
            html,
            /href="login\.html" class="btn [^"]*js-auth-login"/,
            `${file} has a bare site login link`
        );
        assert.doesNotMatch(
            html,
            /href="cadastro\.html" class="btn [^"]*(js-auth-signup|btn-primary)"/,
            `${file} has a bare site signup link`
        );
    }
});

test('desktop deeplink is opened only by the explicit app login route', () => {
    const login = read('login.html');

    assert.match(login, /return params\.get\('app'\) === 'mac';/);
    assert.doesNotMatch(login, /\|\| !getRedirectTarget\(\)/);
    assert.match(login, /function postLoginTarget\(\) \{\s*return getRedirectTarget\(\) \|\| 'account\.html';\s*\}/);
    assert.match(login, /document\.getElementById\('signupLink'\)\.href = appLogin\s*\?\s*'cadastro\.html\?app=mac'\s*:\s*'cadastro\.html\?redirect=account\.html';/);
});

test('desktop deeplink is opened only by the explicit app signup route', () => {
    const signup = read('cadastro.html');

    assert.match(signup, /return params\.get\('app'\) === 'mac';/);
    assert.doesNotMatch(signup, /\|\| !getRedirectTarget\(\)/);
    assert.match(signup, /function postSignupTarget\(\) \{\s*return getRedirectTarget\(\) \|\| 'account\.html';\s*\}/);
    assert.match(signup, /document\.getElementById\('loginLink'\)\.href = shouldOpenApp\(\)\s*\?\s*'login\.html\?app=mac'\s*:\s*'login\.html\?redirect=account\.html';/);
});

test('shared auth script only handles explicitly marked generic forms', () => {
    const auth = read('auth.js');
    const signup = read('cadastro.html');

    assert.match(auth, /loginForm\.dataset\.luumSharedAuth === 'true'/);
    assert.match(auth, /signupForm\.dataset\.luumSharedAuth === 'true'/);
    assert.match(auth, /googleBtn\?\.dataset\.luumSharedAuth === 'true'/);
    assert.doesNotMatch(signup, /data-luum-shared-auth="true"/);
});
