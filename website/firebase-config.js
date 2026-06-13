// ════════════════════════════════════════════════════════
//  Firebase Configuration — Luum
//  ════════════════════════════════════════════════════════
//  CONFIGURAÇÃO ATUAL:
//   - Firebase Auth e Firestore ficam no projeto "luum-app".
//   - O site estático principal fica no Firebase Hosting:
//     https://luum-app.web.app
//   - O backend oficial fica na Vercel:
//     https://luum-app.vercel.app
//   - O app macOS nunca usa Admin SDK local. Ele recebe um Firebase ID token
//     pelo deeplink luum://auth e valida plano/backup nas APIs Vercel.
//  ════════════════════════════════════════════════════════

const firebaseConfig = {
    apiKey: "AIzaSyAWV6ulpYb54Qrta1Fu4iuP9ocnyGNJ99M",
    authDomain: "luum-app.firebaseapp.com",
    projectId: "luum-app",
    storageBucket: "luum-app.firebasestorage.app",
    messagingSenderId: "563728014446",
    appId: "1:563728014446:web:1300e3786b29d9d5485a7f",
    measurementId: "G-Q5T5Z63NQF"
};

window.LUUM_CONFIG = Object.freeze({
    firebase: firebaseConfig,
    apiBase: "https://luum-app.vercel.app",
    siteBase: "https://luum-app.web.app"
});

window.LUUM_API_BASE = window.LUUM_API_BASE || window.LUUM_CONFIG.apiBase;
window.luumApiUrl = function luumApiUrl(path) {
    const base = String(window.LUUM_API_BASE || '').replace(/\/+$/, '');
    const suffix = String(path || '').startsWith('/') ? String(path) : `/${path}`;
    return `${base}${suffix}`;
};

window.luumAuthErrorMessage = function luumAuthErrorMessage(error) {
    const code = String(error?.code || '').trim();
    const message = String(error?.message || error || '').trim();
    const combined = `${code} ${message}`.toLowerCase();

    if (
        error instanceof TypeError ||
        combined.includes('failed to fetch') ||
        combined.includes('networkerror') ||
        combined.includes('cors') ||
        combined.includes('load failed')
    ) {
        return 'Não foi possível falar com a API do Luum. Verifique sua conexão e se o backend Vercel está publicado.';
    }

    const firebaseMessages = {
        'auth/invalid-credential': 'Email ou senha inválidos',
        'auth/wrong-password': 'Email ou senha inválidos',
        'auth/user-not-found': 'Conta não encontrada',
        'auth/invalid-email': 'Email inválido',
        'auth/too-many-requests': 'Muitas tentativas. Aguarde e tente novamente',
        'auth/popup-closed-by-user': 'Login cancelado.',
        'auth/popup-blocked': 'Popup bloqueado pelo navegador.',
        'auth/email-already-in-use': 'Email já cadastrado',
        'auth/weak-password': 'Senha muito fraca (mínimo 6 caracteres)',
        'auth/operation-not-allowed': 'Email/Senha não ativado no Firebase Console'
    };

    if (firebaseMessages[code]) return firebaseMessages[code];
    if (message) return message;
    return 'Não foi possível autenticar agora. Tente novamente em instantes.';
};

// Inicializa Firebase quando o SDK carregou. As páginas mostram um fallback claro
// quando CDN/conexão bloqueiam os scripts do Firebase.
const firebaseSDKReady = typeof firebase !== 'undefined' && typeof firebase.initializeApp === 'function';
if (firebaseSDKReady && !firebase.apps?.length) {
    firebase.initializeApp(firebaseConfig);
}

const auth = firebaseSDKReady && typeof firebase.auth === 'function' ? firebase.auth() : null;
const db = firebaseSDKReady && typeof firebase.firestore === 'function' ? firebase.firestore() : null;

// O backend protegido oferece o diagnóstico real em /api/admin/health.
const firestoreReady = Boolean(db);

// ════════════════════════════════════════════════════════
//  REGRAS DE SEGURANÇA (Firestore)
//  Cole no Console do Firebase → Firestore → Rules
//  ════════════════════════════════════════════════════════
//
//  rules_version = '2';
//  service cloud.firestore {
//    match /databases/{database}/documents {
//
//      match /users/{userId} {
//        // Usuário logado só pode LER o PRÓPRIO documento
//        allow read: if request.auth != null
//                    && request.auth.uid == userId;
//
//        // Ninguém pode escrever diretamente via client
//        // Apenas o Admin SDK (webhook + status) escreve
//        allow write: if false;
//      }
//
//    }
//  }

// ════════════════════════════════════════════════════════
//  ESTRUTURA DO FIRESTORE
//  ════════════════════════════════════════════════════════
//
//  Coleção: "users"
//  Documento: {uid}  ← MESMO uid gerado pelo Firebase Auth
//  ┌─────────────────────────────────────────────┐
//  │  name: "João Silva"                       │
//  │  email: "joao@email.com"                  │
//  │  plan: "profissional"                     │
//  │  createdAt: serverTimestamp               │
//  │  quiz: { cargo, time, tools, objetivo }  │
//  │  subscription: {                          │
//  │    status: "active",                      │
//  │    // active | trial | canceled | past_due │
//  │    stripeCustomerId: "cus_xxx",           │
//  │    stripeSubscriptionId: "sub_xxx",       │
//  │    currentPeriodStart: timestamp,          │
//  │    currentPeriodEnd: timestamp,            │
//  │    updatedAt: serverTimestamp              │
//  │  }                                         │
//  └─────────────────────────────────────────────┘

// ════════════════════════════════════════════════════════
//  COMO O APP DESKTOP LÊ A ASSINATURA
//  ════════════════════════════════════════════════════════
//  Fluxo oficial:
//  1. O usuário entra em login.html?app=mac ou cadastro.html?app=mac.
//  2. O site chama /api/auth/upsert-user com o Firebase ID token.
//  3. O site abre luum://auth?token=...&refreshToken=...&uid=...
//  4. O app macOS valida a sessão em https://luum-app.vercel.app/api/auth/status.
//
//  Exemplo do contrato usado pelo app:
//
//     fetch(luumApiUrl('/api/auth/status'), {
//       headers: { 'Authorization': 'Bearer ' + firebaseToken }
//     })
//     .then(r => r.json())
//     .then(status => {
//       if (status.locked) // mostra paywall
//       else               // libera app
//     });
//
//  FIREBASE_SERVICE_ACCOUNT_JSON deve existir somente no backend Vercel.
//  Nunca coloque chave privada Firebase no app macOS, no site público ou no Git.
//
//  ════════════════════════════════════════════════════════
//  CHECKLIST DE IMPLANTAÇÃO
//  ════════════════════════════════════════════════════════
//
//  [x] 1. Firebase Console → criar projeto (luum-app)
//  [x] 2. Ativar Authentication (Email + Google)
//  [x] 3. Ativar Firestore Database
//  [x] 4. Aplicar regras de segurança
//  [x] 5. firebaseConfig preenchido (firebase-config.js)
//  [x] 6. Stripe Dashboard → criar produtos/preços mensais e anuais
//  [x] 7. Vercel/cofre admin → configurar STRIPE_PRICE_* e STRIPE_* secrets
//  [x] 8. Vercel → configurar FIREBASE_SERVICE_ACCOUNT_JSON e admin inicial
//  [x] 9. Deploy api/checkout.js + api/webhook.js + api/auth/status.js + api/admin/users.js
//  [x] 10. Stripe → configurar webhook → url do api/webhook.js
//  [x] 11. Firebase SDK ativo nos HTMLs
//  [x] 12. App desktop → checkSubscription via /api/auth/status
//  [x] 13. Acessar admin.html com admin inicial e promover usuários
//
//  ════════════════════════════════════════════════════════
