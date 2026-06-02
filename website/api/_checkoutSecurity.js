function checkoutEmail(decodedToken) {
    const email = String(decodedToken?.email || '').trim();
    return email || undefined;
}

module.exports = {
    checkoutEmail
};
