// ════════════════════════════════════════════════════════
//  Firebase Configuration — Luum
//  ════════════════════════════════════════════════════════
//  COMO CONFIGURAR:
//   1. Acesse https://console.firebase.google.com
//   2. Crie um projeto (ex: "luum-prod")
//   3. Ative Authentication:
//      → Sign-in method → Ative "Email/Senha" + "Google"
//   4. Ative Firestore Database:
//      → Criar banco → modo de produção
//      → Cole as regras de segurança abaixo
//   5. Vá em Project Settings → General → Seus apps → Web
//      → Copie o objeto firebaseConfig
//   6. Cole abaixo no lugar dos placeholders (SUA_*)
//   7. Descomente as tags <script> no <head> de:
//      - login.html
//      - cadastro.html
//      - sucesso.html
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

window.LUUM_API_BASE = window.LUUM_API_BASE || "https://luum-app.vercel.app";
window.luumApiUrl = function luumApiUrl(path) {
    const base = String(window.LUUM_API_BASE || '').replace(/\/+$/, '');
    const suffix = String(path || '').startsWith('/') ? String(path) : `/${path}`;
    return `${base}${suffix}`;
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
//  ESCOLHA UMA DAS DUAS FORMAS:
//
//  ─── FORMA A (RECOMENDADA) ───
//  App desktop usa Firebase Admin SDK diretamente:
//
//  1. Crie uma service account:
//     Console Firebase → Project Settings → Service accounts
//     → "Gerar nova chave privada" → baixar service-account.json
//
//  2. No app Electron/Node.js (main process):
//
//     const admin = require('firebase-admin');
//     Use FIREBASE_SERVICE_ACCOUNT_JSON no backend, nunca uma chave privada
//     versionada no repositorio.
//     const db = admin.firestore();
//
//     async function checkSubscription(uid) {
//       const doc = await db.collection('users').doc(uid).get();
//       if (!doc.exists) return { locked: true };
//
//       const { subscription, plan, createdAt } = doc.data();
//       const now = Date.now();
//
//       // Trial
//       if (!subscription || subscription.status === 'trial') {
//         const trialEnd = (createdAt?.toMillis() || now) + 604800000;
//         return { locked: now > trialEnd, plan, trial: true };
//       }
//
//       // Ativa
//       if (subscription.status === 'active') {
//         const end = subscription.currentPeriodEnd?.toMillis() || 0;
//         return { locked: now > end, plan, trial: false };
//       }
//
//       // Cancelada
//       return { locked: true, plan };
//     }
//
//  ─── FORMA B (via API) ───
//  App desktop chama o endpoint /api/auth/status:
//
//     fetch('https://sua-api.com/api/auth/status', {
//       headers: { 'Authorization': 'Bearer ' + firebaseToken }
//     })
//     .then(r => r.json())
//     .then(status => {
//       if (status.locked) // mostra paywall
//       else               // libera app
//     });
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
