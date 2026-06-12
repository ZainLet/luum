const test = require('node:test');
const assert = require('node:assert/strict');

const {
    configuredDeviceLimit,
    deviceSecurityPatch,
    evaluateDeviceAccess,
    knownDeviceIDs,
    normalizedDeviceID
} = require('../api/_deviceSecurity');

test('normalizes only hashed Luum device ids', () => {
    const valid = 'a'.repeat(64);
    assert.equal(normalizedDeviceID({ headers: { 'x-luum-device-id': `  ${valid.toUpperCase()}  ` } }), valid);
    assert.equal(normalizedDeviceID({ headers: { 'x-luum-device-id': 'not-a-device' } }), '');
    assert.equal(normalizedDeviceID({ headers: {} }), '');
});

test('uses a conservative bounded device limit', () => {
    const original = process.env.LUUM_MAX_DEVICES_PER_USER;
    try {
        delete process.env.LUUM_MAX_DEVICES_PER_USER;
        assert.equal(configuredDeviceLimit(), 2);

        process.env.LUUM_MAX_DEVICES_PER_USER = '4';
        assert.equal(configuredDeviceLimit(), 4);

        process.env.LUUM_MAX_DEVICES_PER_USER = '0';
        assert.equal(configuredDeviceLimit(), 2);

        process.env.LUUM_MAX_DEVICES_PER_USER = '999';
        assert.equal(configuredDeviceLimit(), 10);
    } finally {
        if (original === undefined) delete process.env.LUUM_MAX_DEVICES_PER_USER;
        else process.env.LUUM_MAX_DEVICES_PER_USER = original;
    }
});

test('allows known devices and blocks new devices above the limit', () => {
    const deviceOne = '1'.repeat(64);
    const deviceTwo = '2'.repeat(64);
    const deviceThree = '3'.repeat(64);
    const account = {
        security: {
            devices: {
                [deviceOne]: { firstSeenAt: 'old' },
                [deviceTwo]: { firstSeenAt: 'old' }
            }
        }
    };

    assert.deepEqual(knownDeviceIDs(account), [deviceOne, deviceTwo]);
    assert.equal(evaluateDeviceAccess(account, deviceOne).allowed, true);

    const blocked = evaluateDeviceAccess(account, deviceThree);
    assert.equal(blocked.allowed, false);
    assert.equal(blocked.reason, 'device_limit_exceeded');
    assert.equal(blocked.limit, 2);
});

test('builds Firestore patches without leaking raw token data', () => {
    const now = { __serverTimestamp: true };
    const admin = {
        firestore: {
            FieldValue: {
                serverTimestamp() {
                    return now;
                }
            }
        }
    };
    const deviceID = 'f'.repeat(64);

    const newDevice = deviceSecurityPatch(admin, deviceID);
    assert.equal(newDevice.security.lastDeviceID, deviceID);
    assert.equal(newDevice[`security.devices.${deviceID}`].firstSeenAt, now);
    assert.equal(newDevice[`security.devices.${deviceID}`].lastSeenAt, now);

    const existingLimitExceeded = deviceSecurityPatch(admin, deviceID, { allowNewDevice: false });
    assert.equal(existingLimitExceeded.security.lastDeviceID, deviceID);
    assert.equal(existingLimitExceeded[`security.devices.${deviceID}.lastSeenAt`], now);
    assert.equal(Object.hasOwn(existingLimitExceeded, `security.devices.${deviceID}`), false);
});
