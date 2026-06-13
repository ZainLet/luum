(function () {
    const STORAGE_USER_KEY = 'luum_user';

    function apiUrl(path) {
        if (window.luumApiUrl) return window.luumApiUrl(path);
        const base = String(window.LUUM_API_BASE || window.LUUM_CONFIG?.apiBase || '').replace(/\/+$/, '');
        if (!base) throw new Error('Configuração da API do Luum não carregou.');
        const suffix = String(path || '').startsWith('/') ? String(path) : `/${path}`;
        return `${base}${suffix}`;
    }

    function getFirebaseAuth() {
        if (typeof firebase === 'undefined' || !firebase.auth) return null;
        return firebase.auth();
    }

    function authErrorMessage(error) {
        const mapped = typeof window.luumAuthErrorMessage === 'function'
            ? window.luumAuthErrorMessage(error)
            : '';
        return mapped || error?.message || 'Não foi possível autenticar agora.';
    }

    function getStoredUser() {
        try {
            const raw = localStorage.getItem(STORAGE_USER_KEY);
            return raw ? JSON.parse(raw) : null;
        } catch {
            return null;
        }
    }

    function rememberUser(user) {
        if (!user) {
            localStorage.removeItem(STORAGE_USER_KEY);
            return;
        }

        localStorage.setItem(STORAGE_USER_KEY, JSON.stringify({
            uid: user.uid || user.email,
            email: user.email || '',
            name: user.displayName || user.name || (user.email || 'Usuario').split('@')[0]
        }));
    }

    function setAuthButtons(user) {
        const loginBtns = document.querySelectorAll('.js-auth-login');
        const signupBtns = document.querySelectorAll('.js-auth-signup');

        loginBtns.forEach((el) => {
            el.textContent = user ? 'Minha Conta' : 'Entrar';
            el.href = user ? 'account.html' : 'login.html?redirect=account.html';
            el.className = 'btn btn-secondary js-auth-login';
        });

        signupBtns.forEach((el) => {
            el.textContent = user ? 'Sair' : 'Comecar Gratis';
            el.href = user ? '#' : 'cadastro.html?redirect=account.html';
            el.className = user ? 'btn btn-secondary js-auth-signup' : 'btn btn-primary js-auth-signup';
            el.onclick = user ? signOut : null;
        });
    }

    async function signOut(event) {
        event.preventDefault();
        const auth = getFirebaseAuth();
        try {
            if (auth) await auth.signOut();
        } finally {
            rememberUser(null);
            window.location.href = 'index.html';
        }
    }

    async function redirectToApp(user) {
        const auth = getFirebaseAuth();
        const currentUser = auth?.currentUser || user;
        if (!currentUser?.getIdToken || !currentUser.uid) {
            throw new Error('Sessao Firebase incompleta para abrir o app.');
        }

        const token = await upsertAccount(currentUser);
        const refreshToken = currentUser.refreshToken || '';
        const redirectURL = `luum://auth?token=${encodeURIComponent(token)}&refreshToken=${encodeURIComponent(refreshToken)}&uid=${encodeURIComponent(currentUser.uid)}`;

        const fallback = window.setTimeout(() => {
            window.location.href = 'account.html';
        }, 900);

        document.addEventListener('visibilitychange', () => {
            if (document.hidden) window.clearTimeout(fallback);
        }, { once: true });

        window.location.href = redirectURL;
    }

    function getRedirectTarget() {
        const params = new URLSearchParams(window.location.search);
        const redirect = params.get('redirect');
        if (!redirect) return 'account.html';

        const target = new URL(redirect, window.location.href);
        if (target.origin !== window.location.origin) return 'account.html';
        return `${target.pathname.replace(/^\//, '')}${target.search}${target.hash}`;
    }

    function shouldOpenApp() {
        return new URLSearchParams(window.location.search).get('app') === 'mac';
    }

    async function finishAuth(user) {
        if (shouldOpenApp()) {
            await redirectToApp(user);
            return;
        }

        await upsertAccount(user);
        window.location.href = getRedirectTarget();
    }

    async function upsertAccount(user) {
        const token = await user.getIdToken(true);
        let response;
        try {
            response = await fetch(apiUrl('/api/auth/upsert-user'), {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    email: user.email || '',
                    name: user.displayName || ''
                })
            });
        } catch (error) {
            throw new Error(authErrorMessage(error));
        }
        const data = await response.json().catch(() => ({}));
        if (!response.ok) {
            throw new Error(data.error || 'Backend de conta indisponivel.');
        }
        return token;
    }

    async function currentCheckoutUser() {
        const auth = getFirebaseAuth();
        if (auth?.currentUser) return auth.currentUser;

        return getStoredUser();
    }

    function loginRedirect(plan) {
        const currentPage = `${window.location.pathname.split('/').pop() || 'vendas.html'}${window.location.search}`;
        return `login.html?redirect=${encodeURIComponent(currentPage)}&plan=${encodeURIComponent(plan)}`;
    }

    function attachCheckoutButtons() {
        document.querySelectorAll('[data-checkout]').forEach((btn) => {
            btn.addEventListener('click', async (event) => {
                event.preventDefault();

                const plan = btn.dataset.plan || btn.dataset.checkout;
                const billingToggle = document.querySelector('.toggle-btn.active');
                const billing = billingToggle?.dataset.billing || btn.dataset.billing || 'monthly';
                const minimumSeats = Number.parseInt(btn.dataset.minSeats || '1', 10);
                let quantity = Number.isInteger(minimumSeats) && minimumSeats > 0 ? minimumSeats : 1;
                const user = await currentCheckoutUser();

                if (!user || typeof user.getIdToken !== 'function') {
                    window.location.href = loginRedirect(plan);
                    return;
                }

                btn.disabled = true;
                const originalText = btn.textContent;
                btn.textContent = 'Abrindo checkout...';

                try {
                    if (quantity > 1) {
                        const answer = window.prompt(`Quantos assentos deseja contratar? Mínimo: ${quantity}.`, String(quantity));
                        if (answer === null) return;
                        const parsed = Number.parseInt(answer, 10);
                        if (!Number.isInteger(parsed) || parsed < quantity || parsed > 1000) {
                            throw new Error(`Informe uma quantidade entre ${quantity} e 1000 assentos.`);
                        }
                        quantity = parsed;
                    }

                    const token = await user.getIdToken();
                    const response = await fetch(apiUrl('/api/checkout'), {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            ...(token ? { Authorization: `Bearer ${token}` } : {})
                        },
                        body: JSON.stringify({
                            plan,
                            billing,
                            quantity,
                            uid: user.uid || user.email
                        })
                    });

                    const data = await response.json().catch(() => ({}));
                    if (!response.ok || !data.url) {
                        throw new Error(data.error || 'Checkout indisponivel.');
                    }

                    window.location.href = data.url;
                } catch (error) {
                    console.error('[Luum Checkout]', error);
                    alert(error.message || 'Checkout indisponivel agora. Tente novamente em instantes.');
                } finally {
                    btn.disabled = false;
                    btn.textContent = originalText;
                }
            });
        });
    }

    function attachAuthForms() {
        const loginForm = document.getElementById('loginForm');
        const signupForm = document.getElementById('signupForm');
        const googleBtn = document.getElementById('googleSignIn');
        const loginFieldsReady = Boolean(
            loginForm &&
            loginForm.dataset.luumSharedAuth === 'true' &&
            document.getElementById('email') &&
            document.getElementById('password')
        );
        const signupFieldsReady = Boolean(
            signupForm &&
            signupForm.dataset.luumSharedAuth === 'true' &&
            document.getElementById('signupName') &&
            document.getElementById('signupEmail') &&
            document.getElementById('signupPassword')
        );

        if (loginFieldsReady) {
            loginForm.addEventListener('submit', async (event) => {
                event.preventDefault();
                const auth = getFirebaseAuth();
                const email = document.getElementById('email')?.value.trim();
                const password = document.getElementById('password')?.value;
                if (!email || !password || !auth) return;

                const credential = await auth.signInWithEmailAndPassword(email, password);
                rememberUser(credential.user);
                await finishAuth(credential.user);
            });
        }

        if (signupFieldsReady) {
            signupForm.addEventListener('submit', async (event) => {
                event.preventDefault();
                const auth = getFirebaseAuth();
                const name = document.getElementById('signupName')?.value.trim();
                const email = document.getElementById('signupEmail')?.value.trim();
                const password = document.getElementById('signupPassword')?.value;
                if (!name || !email || !password || !auth) return;

                const credential = await auth.createUserWithEmailAndPassword(email, password);
                await credential.user.updateProfile({ displayName: name });
                rememberUser(credential.user);
                await finishAuth(credential.user);
            });
        }

        if (googleBtn?.dataset.luumSharedAuth === 'true') {
            googleBtn.addEventListener('click', async () => {
                const auth = getFirebaseAuth();
                if (!auth || !firebase.auth?.GoogleAuthProvider) return;

                const provider = new firebase.auth.GoogleAuthProvider();
                const credential = await auth.signInWithPopup(provider);
                rememberUser(credential.user);
                await finishAuth(credential.user);
            });
        }
    }

    document.addEventListener('DOMContentLoaded', () => {
        const auth = getFirebaseAuth();
        attachAuthForms();
        attachCheckoutButtons();

        if (auth) {
            auth.onAuthStateChanged((user) => {
                rememberUser(user);
                setAuthButtons(user || getStoredUser());
            });
        } else {
            setAuthButtons(getStoredUser());
        }
    });
})();
