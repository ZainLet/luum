const PUBLIC_SITE_URL = 'https://luum-app.web.app';
const FIREBASE_HOSTING_URL = 'https://luum-app.firebaseapp.com';
const API_BASE_URL = 'https://luum-app.vercel.app';

const OFFICIAL_ORIGINS = Object.freeze([
    PUBLIC_SITE_URL,
    FIREBASE_HOSTING_URL,
    API_BASE_URL
]);

function trimTrailingSlash(value) {
    return String(value || '').trim().replace(/\/+$/, '');
}

function officialSiteURL(candidate) {
    const normalized = trimTrailingSlash(candidate || PUBLIC_SITE_URL);
    return normalized === PUBLIC_SITE_URL ? PUBLIC_SITE_URL : null;
}

function webhookURL(path = '/api/webhook') {
    const suffix = String(path || '').startsWith('/') ? String(path) : `/${path}`;
    return `${API_BASE_URL}${suffix}`;
}

module.exports = {
    API_BASE_URL,
    FIREBASE_HOSTING_URL,
    OFFICIAL_ORIGINS,
    PUBLIC_SITE_URL,
    officialSiteURL,
    trimTrailingSlash,
    webhookURL
};
