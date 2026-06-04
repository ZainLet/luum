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

function sanitizedPayloadForStorage(payload) {
    if (!payload || typeof payload !== 'object') return payload;

    const sanitized = JSON.parse(JSON.stringify(payload));

    if (sanitized.monitoringPreferences?.zapierSettings) {
        sanitized.monitoringPreferences.zapierSettings.webhookURL = '';
    }

    if (sanitized.googleCalendarSnapshot) {
        sanitized.googleCalendarSnapshot.clientSecret = '';

        if (Array.isArray(sanitized.googleCalendarSnapshot.connections)) {
            sanitized.googleCalendarSnapshot.connections = sanitized.googleCalendarSnapshot.connections.map((connection) => ({
                ...connection,
                agendaDay: null,
                agendaItems: [],
                legacyTokens: null,
                tokens: null
            }));
        }
    }

    return sanitized;
}

module.exports = {
    payloadForEntitlement,
    payloadAccountMatchesFirebaseUID,
    payloadAccountUID,
    payloadSize,
    sanitizedPayloadForStorage
};
