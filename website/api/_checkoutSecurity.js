const { officialSiteURL } = require('./_publicConfig');

function checkoutEmail(decodedToken) {
    const email = String(decodedToken?.email || '').trim();
    return email || undefined;
}

function checkoutSiteURL(candidate) {
    return officialSiteURL(candidate);
}

module.exports = {
    checkoutEmail,
    checkoutSiteURL
};
