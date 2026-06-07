function checkoutEmail(decodedToken) {
    const email = String(decodedToken?.email || '').trim();
    return email || undefined;
}

function checkoutSiteURL(candidate) {
    const official = 'https://luum-app.web.app';
    const normalized = String(candidate || official).trim().replace(/\/+$/, '');
    return normalized === official ? official : null;
}

module.exports = {
    checkoutEmail,
    checkoutSiteURL
};
