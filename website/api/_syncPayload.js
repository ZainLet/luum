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

function payloadForEntitlement(payload, entitlement, includesFeature) {
    if (!payload || typeof payload !== 'object') return payload;
    if (typeof includesFeature !== 'function' || includesFeature(entitlement, 'rawActivityBackup')) {
        return payload;
    }

    return {
        ...payload,
        rawActivities: null
    };
}

module.exports = {
    payloadForEntitlement,
    payloadAccountMatchesFirebaseUID,
    payloadAccountUID,
    payloadSize
};
