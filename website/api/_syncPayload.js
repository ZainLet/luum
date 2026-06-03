function payloadSize(payload) {
    return Buffer.byteLength(JSON.stringify(payload), 'utf8');
}

function payloadAccountUID(payload) {
    return String(payload?.account?.uid || '').trim();
}

function payloadAccountMatchesFirebaseUID(payload, uid) {
    const accountUID = payloadAccountUID(payload);
    return !accountUID || accountUID === uid;
}

module.exports = {
    payloadAccountMatchesFirebaseUID,
    payloadAccountUID,
    payloadSize
};
