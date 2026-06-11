const DEFAULT_DEVICE_LIMIT = 2;

function normalizedDeviceID(req) {
    const raw = req.headers['x-luum-device-id'];
    const value = String(Array.isArray(raw) ? raw[0] : raw || '').trim().toLowerCase();
    if (!/^[a-f0-9]{64}$/.test(value)) return '';
    return value;
}

function configuredDeviceLimit() {
    const parsed = Number.parseInt(process.env.LUUM_MAX_DEVICES_PER_USER || String(DEFAULT_DEVICE_LIMIT), 10);
    if (!Number.isInteger(parsed) || parsed < 1) return DEFAULT_DEVICE_LIMIT;
    return Math.min(parsed, 10);
}

function knownDeviceIDs(data = {}) {
    const devices = data.security?.devices;
    if (!devices || typeof devices !== 'object' || Array.isArray(devices)) return [];
    return Object.keys(devices)
        .map((deviceID) => String(deviceID || '').trim().toLowerCase())
        .filter((deviceID) => /^[a-f0-9]{64}$/.test(deviceID));
}

function evaluateDeviceAccess(data = {}, deviceID = '') {
    const normalized = String(deviceID || '').trim().toLowerCase();
    if (!normalized) return { allowed: true, tracked: false };

    const devices = knownDeviceIDs(data);
    const limit = configuredDeviceLimit();
    if (devices.includes(normalized) || devices.length < limit) {
        return { allowed: true, tracked: true, limit };
    }

    return {
        allowed: false,
        tracked: true,
        limit,
        reason: 'device_limit_exceeded'
    };
}

function deviceSecurityPatch(admin, deviceID, { allowNewDevice = true } = {}) {
    const now = admin.firestore.FieldValue.serverTimestamp();
    const patch = {
        security: {
            lastDeviceID: deviceID,
            lastDeviceSeenAt: now
        }
    };

    if (allowNewDevice) {
        patch[`security.devices.${deviceID}`] = {
            firstSeenAt: now,
            lastSeenAt: now
        };
    } else {
        patch[`security.devices.${deviceID}.lastSeenAt`] = now;
    }

    return patch;
}

module.exports = {
    configuredDeviceLimit,
    deviceSecurityPatch,
    evaluateDeviceAccess,
    knownDeviceIDs,
    normalizedDeviceID
};
