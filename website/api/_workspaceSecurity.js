const crypto = require('node:crypto');

const ID_PATTERN = /^[a-zA-Z0-9][a-zA-Z0-9_-]{1,127}$/;

function validID(value) {
    return ID_PATTERN.test(String(value || '').trim());
}

function secretHash(secret) {
    return crypto.createHash('sha256').update(String(secret || '').trim(), 'utf8').digest('hex');
}

function sameHash(left, right) {
    const a = Buffer.from(String(left || ''), 'hex');
    const b = Buffer.from(String(right || ''), 'hex');
    return a.length === b.length && a.length > 0 && crypto.timingSafeEqual(a, b);
}

module.exports = { sameHash, secretHash, validID };
