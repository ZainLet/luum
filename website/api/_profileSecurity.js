function profileEmail(decodedToken) {
    const email = String(decodedToken?.email || '').trim().toLowerCase();
    return email || null;
}

function profileText(primary, fallback, maxLength = 200) {
    const text = String(primary || fallback || '').trim();
    return text ? text.slice(0, maxLength) : null;
}

module.exports = {
    profileEmail,
    profileText
};
