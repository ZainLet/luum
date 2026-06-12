const test = require('node:test');
const assert = require('node:assert/strict');

const firebaseAdminPath = require.resolve('../api/_firebaseAdmin');
require.cache[firebaseAdminPath] = {
    id: firebaseAdminPath,
    filename: firebaseAdminPath,
    loaded: true,
    exports: {
        admin: {},
        getAdminApp() {
            return {};
        },
        getFirestore() {
            return {};
        }
    }
};

const { userResponse } = require('../api/_adminActions');

test('admin user response summarizes device security without exposing device hashes', () => {
    const deviceID = 'a'.repeat(64);
    const response = userResponse(
        {
            uid: 'firebase-user',
            email: 'user@luum.app',
            displayName: 'User',
            customClaims: {}
        },
        {
            plan: 'profissional',
            subscription: { status: 'active' },
            security: {
                devices: {
                    [deviceID]: {
                        firstSeenAt: 'old'
                    }
                },
                lastDeviceSeenAt: 'last-seen',
                devicesClearedAt: 'cleared-at'
            }
        }
    );

    assert.equal(response.security.deviceCount, 1);
    assert.equal(response.security.lastDeviceSeenAt, 'last-seen');
    assert.equal(response.security.devicesClearedAt, 'cleared-at');
    assert.equal(JSON.stringify(response).includes(deviceID), false);
});
