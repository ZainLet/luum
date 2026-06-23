function addNoStoreHeaders(res) {
    res.setHeader('Cache-Control', 'no-store, max-age=0');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
}

function applySecurityHeaders(res) {
    addNoStoreHeaders(res);
}

module.exports = { addNoStoreHeaders, applySecurityHeaders };
