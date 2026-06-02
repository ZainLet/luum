const admin = require('firebase-admin');

function credentialFromEnv() {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!raw) return null;

    const parsed = JSON.parse(raw);
    if (parsed.private_key) {
        parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
    }
    return admin.credential.cert(parsed);
}

function getAdminApp() {
    if (admin.apps.length) return admin.app();

    const credential = credentialFromEnv() || admin.credential.applicationDefault();
    return admin.initializeApp({ credential });
}

function getFirestore() {
    return getAdminApp().firestore();
}

module.exports = { admin, getAdminApp, getFirestore };
