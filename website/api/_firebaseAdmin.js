const {
    applicationDefault,
    cert,
    getApp,
    getApps,
    initializeApp
} = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const {
    FieldValue,
    Timestamp,
    getFirestore: getFirestoreForApp
} = require('firebase-admin/firestore');

function credentialFromEnv() {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!raw) return null;

    const parsed = JSON.parse(raw);
    if (parsed.private_key) {
        parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
    }
    return cert(parsed);
}

function getAdminApp() {
    if (getApps().length) return getApp();

    const credential = credentialFromEnv() || applicationDefault();
    return initializeApp({ credential });
}

function getFirestore() {
    return getFirestoreForApp(getAdminApp());
}

// Preserve the small namespace used by the handlers while firebase-admin 13.6
// exposes Auth and Firestore only through its modular entrypoints.
const firestore = Object.assign(
    () => getFirestore(),
    { FieldValue, Timestamp }
);

const admin = {
    auth: () => getAuth(getAdminApp()),
    firestore
};

module.exports = { admin, getAdminApp, getFirestore };
