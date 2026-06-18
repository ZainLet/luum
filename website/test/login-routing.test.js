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
    assert.match(login, /function authRequestState\(\)/);
    assert.match(login, /state: callbackState/);
    assert.doesNotMatch(login, /\|\| !getRedirectTarget\(\)/);
    assert.match(login, /user\.getIdToken\(true\)/);
    assert.match(login, /function postLoginTarget\(\) \{\s*return getRedirectTarget\(\) \|\| 'account\.html';\s*\}/);
    assert.match(login, /cadastro\.html\?app=mac&state=\$\{encodeURIComponent\(callbackState\)\}/);
});

test('app login confirms existing browser account before opening the desktop app', () => {
    const login = read('login.html');

    assert.match(login, /id="accountChoice"/);
    assert.match(login, /function renderExistingAppSession\(user\)/);
    assert.match(login, /Confirme antes de abrir o app/);
    assert.match(login, /if \(appLogin\) \{\s*renderExistingAppSession\(user\);\s*return;\s*\}/);
    assert.match(login, /id="continueCurrentAccount"/);
    assert.match(login, /id="switchCurrentAccount"/);
    assert.match(login, /function escapeHTML\(value\)/);
});

test('desktop deeplink is opened only by the explicit app signup route', () => {
    const signup = read('cadastro.html');

    assert.match(signup, /return params\.get\('app'\) === 'mac';/);
    assert.match(signup, /function authRequestState\(\)/);
    assert.match(signup, /state: callbackState/);
    assert.doesNotMatch(signup, /\|\| !getRedirectTarget\(\)/);
    assert.match(signup, /user\.getIdToken\(true\)/);
    assert.match(signup, /function postSignupTarget\(\) \{\s*return getRedirectTarget\(\) \|\| 'account\.html';\s*\}/);
    assert.match(signup, /login\.html\?app=mac&state=\$\{encodeURIComponent\(callbackState\)\}/);
});

test('app signup reuses existing browser sessions only after login account confirmation', () => {
    const signup = read('cadastro.html');

    assert.match(signup, /if \(shouldOpenApp\(\)\) \{\s*window\.location\.href = `login\.html\?app=mac&state=\$\{encodeURIComponent\(callbackState\)\}`;\s*return;\s*\}/);
    assert.match(signup, /if \(user && !signingUp\) \{/);
});

test('shared auth script only handles explicitly marked generic forms', () => {
    const auth = read('auth.js');
    const signup = read('cadastro.html');

    assert.match(auth, /loginForm\.dataset\.luumSharedAuth === 'true'/);
    assert.match(auth, /signupForm\.dataset\.luumSharedAuth === 'true'/);
    assert.match(auth, /googleBtn\?\.dataset\.luumSharedAuth === 'true'/);
    assert.doesNotMatch(signup, /data-luum-shared-auth="true"/);
});

test('shared auth script opens desktop app only for explicit app route', () => {
    const auth = read('auth.js');

    assert.match(auth, /function shouldOpenApp\(\) \{\s*return new URLSearchParams\(window\.location\.search\)\.get\('app'\) === 'mac';\s*\}/);
    assert.match(auth, /function authRequestState\(\)/);
    assert.match(auth, /state: callbackState/);
    assert.match(auth, /if \(shouldOpenApp\(\)\) \{\s*await redirectToApp\(user\);\s*return;\s*\}/);
    assert.match(auth, /window\.location\.href = getRedirectTarget\(\);/);
});

test('only auth entry pages can emit the desktop auth callback', () => {
    const allowed = new Set(['login.html', 'cadastro.html', 'auth.js']);
    const candidates = fs.readdirSync(root).filter((name) => name.endsWith('.html') || name === 'auth.js');

    for (const file of candidates) {
        if (allowed.has(file)) continue;
        assert.doesNotMatch(read(file), /luum:\/\/auth/, `${file} must not bypass the app login state`);
    }
});

test('auth pages use a shared friendly error mapper for API and Firebase failures', () => {
    const firebaseConfig = read('firebase-config.js');
    const auth = read('auth.js');
    const login = read('login.html');
    const signup = read('cadastro.html');
    const account = read('account.html');

    assert.match(firebaseConfig, /window\.luumAuthErrorMessage = function luumAuthErrorMessage\(error\)/);
    assert.match(firebaseConfig, /failed to fetch/);
    assert.match(firebaseConfig, /backend Vercel está publicado/);
    assert.match(firebaseConfig, /auth\/invalid-credential/);
    assert.match(auth, /throw new Error\(authErrorMessage\(error\)\)/);
    assert.match(login, /showError\('Erro ao autenticar: ' \+ authErrorMessage\(error\)\)/);
    assert.match(signup, /showError\('Erro: ' \+ authErrorMessage\(error\)\)/);
    assert.match(account, /showAccountError\(authErrorMessage\(err\)\)/);
});

test('pages use the current auth.js cache-busting version', () => {
    for (const file of fs.readdirSync(root).filter((name) => name.endsWith('.html'))) {
        const html = read(file);
        if (!html.includes('auth.js')) continue;

        assert.doesNotMatch(html, /auth\.js\?v=[0-9]\b/, `${file} references an old auth.js version`);
        assert.match(html, /auth\.js\?v=10\b/, `${file} should use auth.js?v=10`);
    }
});

test('pages use the current firebase-config.js cache-busting version', () => {
    for (const file of fs.readdirSync(root).filter((name) => name.endsWith('.html'))) {
        const html = read(file);
        if (!html.includes('firebase-config.js')) continue;

        assert.doesNotMatch(html, /firebase-config\.js["']/u, `${file} references firebase-config.js without a version`);
        assert.doesNotMatch(html, /firebase-config\.js\?v=[0-9]\b/u, `${file} references an old firebase-config.js version`);
        assert.match(html, /firebase-config\.js\?v=10\b/u, `${file} should use firebase-config.js?v=10`);
    }
});
