const crypto = require('crypto');
const { admin, getFirestore } = require('./_firebaseAdmin');

const SETTINGS = {
    STRIPE_PUBLISHABLE_KEY: { category: 'stripe', label: 'Stripe publishable key', env: 'STRIPE_PUBLISHABLE_KEY' },
    STRIPE_SECRET_KEY: { category: 'stripe', label: 'Stripe secret key', env: 'STRIPE_SECRET_KEY' },
    STRIPE_WEBHOOK_SECRET: { category: 'stripe', label: 'Stripe webhook secret', env: 'STRIPE_WEBHOOK_SECRET' },
    STRIPE_PRICE_ESSENCIAL_MONTHLY: { category: 'stripe', label: 'Essencial mensal', env: 'STRIPE_PRICE_ESSENCIAL_MONTHLY' },
    STRIPE_PRICE_ESSENCIAL_ANNUALLY: { category: 'stripe', label: 'Essencial anual', env: 'STRIPE_PRICE_ESSENCIAL_ANNUALLY' },
    STRIPE_PRICE_PROFISSIONAL_MONTHLY: { category: 'stripe', label: 'Profissional mensal', env: 'STRIPE_PRICE_PROFISSIONAL_MONTHLY' },
    STRIPE_PRICE_PROFISSIONAL_ANNUALLY: { category: 'stripe', label: 'Profissional anual', env: 'STRIPE_PRICE_PROFISSIONAL_ANNUALLY' },
    STRIPE_PRICE_EQUIPES_MONTHLY: { category: 'stripe', label: 'Equipes mensal', env: 'STRIPE_PRICE_EQUIPES_MONTHLY' },
    STRIPE_PRICE_EQUIPES_ANNUALLY: { category: 'stripe', label: 'Equipes anual', env: 'STRIPE_PRICE_EQUIPES_ANNUALLY' },
    STRIPE_PRICE_NEGOCIOS_MONTHLY: { category: 'stripe', label: 'Negócios mensal', env: 'STRIPE_PRICE_NEGOCIOS_MONTHLY' },
    STRIPE_PRICE_NEGOCIOS_ANNUALLY: { category: 'stripe', label: 'Negócios anual', env: 'STRIPE_PRICE_NEGOCIOS_ANNUALLY' },
    PUBLIC_SITE_URL: { category: 'site', label: 'URL pública do site', env: 'PUBLIC_SITE_URL' },
    GOOGLE_CALENDAR_CLIENT_ID: { category: 'app', label: 'Google Calendar Client ID', env: 'GOOGLE_CALENDAR_CLIENT_ID' },
    OUTLOOK_CLIENT_ID: { category: 'app', label: 'Microsoft Outlook Client ID', env: 'OUTLOOK_CLIENT_ID' },
    NOTION_INTEGRATION_TOKEN: { category: 'app', label: 'Notion integration token', env: 'NOTION_INTEGRATION_TOKEN' },
    NOTION_CLIENT_ID: { category: 'app', label: 'Notion OAuth client ID', env: 'NOTION_CLIENT_ID' },
    NOTION_CLIENT_SECRET: { category: 'app', label: 'Notion OAuth client secret', env: 'NOTION_CLIENT_SECRET' },
    CLICKUP_API_TOKEN: { category: 'app', label: 'ClickUp API token', env: 'CLICKUP_API_TOKEN' },
    CLICKUP_WEBHOOK_SECRET: { category: 'app', label: 'ClickUp webhook secret', env: 'CLICKUP_WEBHOOK_SECRET' },
    LINEAR_API_KEY: { category: 'app', label: 'Linear API key', env: 'LINEAR_API_KEY' },
    LINEAR_CLIENT_ID: { category: 'app', label: 'Linear OAuth client ID', env: 'LINEAR_CLIENT_ID' },
    LINEAR_CLIENT_SECRET: { category: 'app', label: 'Linear OAuth client secret', env: 'LINEAR_CLIENT_SECRET' },
    ZAPIER_WEBHOOK_URL: { category: 'app', label: 'Zapier webhook URL', env: 'ZAPIER_WEBHOOK_URL' }
};

const SETTINGS_REF = ['config', 'integrations'];
let cachedSettings = null;
let cacheExpiresAt = 0;

function encryptionKey() {
    const raw = String(process.env.LUUM_SETTINGS_ENCRYPTION_KEY || '').trim();
    if (!raw) {
        throw new Error('LUUM_SETTINGS_ENCRYPTION_KEY não configurada');
    }
    return crypto.createHash('sha256').update(raw).digest();
}

function encrypt(value) {
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey(), iv);
    const encrypted = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
    return ['v1', iv.toString('base64'), cipher.getAuthTag().toString('base64'), encrypted.toString('base64')].join('.');
}

function decrypt(value) {
    const [version, iv, tag, encrypted] = String(value || '').split('.');
    if (version !== 'v1' || !iv || !tag || !encrypted) throw new Error('Configuração criptografada inválida');
    const decipher = crypto.createDecipheriv('aes-256-gcm', encryptionKey(), Buffer.from(iv, 'base64'));
    decipher.setAuthTag(Buffer.from(tag, 'base64'));
    return Buffer.concat([decipher.update(Buffer.from(encrypted, 'base64')), decipher.final()]).toString('utf8');
}

function settingRef() {
    return getFirestore().collection(SETTINGS_REF[0]).doc(SETTINGS_REF[1]);
}

async function storedSettings({ fresh = false } = {}) {
    if (!fresh && cachedSettings && Date.now() < cacheExpiresAt) return cachedSettings;
    const snap = await settingRef().get();
    const encryptedValues = snap.exists ? snap.data()?.values || {} : {};
    const values = {};
    for (const key of Object.keys(SETTINGS)) {
        if (encryptedValues[key]) values[key] = decrypt(encryptedValues[key]);
    }
    cachedSettings = values;
    cacheExpiresAt = Date.now() + 30_000;
    return values;
}

async function getSetting(key) {
    if (!SETTINGS[key]) return '';
    const fromEnvironment = String(process.env[SETTINGS[key].env] || '').trim();
    if (fromEnvironment) return fromEnvironment;
    const stored = await storedSettings();
    return String(stored[key] || '').trim();
}

async function saveSettings(updates, updatedBy) {
    const encryptedUpdates = {};
    for (const [key, rawValue] of Object.entries(updates || {})) {
        if (!SETTINGS[key]) continue;
        const value = String(rawValue || '').trim();
        if (!value) continue;
        if (value.length > 4096) throw new Error(`Valor muito longo: ${key}`);
        encryptedUpdates[key] = encrypt(value);
    }
    if (!Object.keys(encryptedUpdates).length) throw new Error('Preencha ao menos uma configuração');

    await settingRef().set({
        values: encryptedUpdates,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: updatedBy?.uid || null,
        updatedByEmail: updatedBy?.email || null
    }, { merge: true });
    cachedSettings = null;
    cacheExpiresAt = 0;
}

function mask(value) {
    const text = String(value || '');
    if (!text) return '';
    if (text.length <= 8) return '••••••••';
    return `${text.slice(0, 4)}••••${text.slice(-4)}`;
}

async function maskedSettings() {
    const values = {};
    for (const [key, metadata] of Object.entries(SETTINGS)) {
        const resolved = await getSetting(key);
        values[key] = {
            ...metadata,
            configured: Boolean(resolved),
            masked: mask(resolved)
        };
    }
    return values;
}

module.exports = { SETTINGS, getSetting, maskedSettings, saveSettings };
