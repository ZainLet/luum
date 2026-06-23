const test = require('node:test');
const assert = require('node:assert/strict');
const { checkRateLimit, resetAll } = require('../api/_rateLimit');

test.beforeEach(() => resetAll());

function req(opts = {}) {
    return {
        headers: { ...(opts.auth ? { authorization: `Bearer ${opts.auth}` } : {}), ...opts.headers },
        socket: { remoteAddress: opts.ip || '127.0.0.1' }
    };
}

test('allows requests under the limit', () => {
    for (let i = 0; i < 5; i++) {
        const result = checkRateLimit(req(), { windowMs: 60_000, max: 10, key: 'test' });
        assert.equal(result.limited, false);
        assert.equal(result.retryAfter, undefined);
    }
});

test('blocks requests at the limit', () => {
    const max = 3;
    for (let i = 0; i < max; i++) {
        const result = checkRateLimit(req(), { windowMs: 60_000, max, key: 'test' });
        assert.equal(result.limited, false);
    }
    const blocked = checkRateLimit(req(), { windowMs: 60_000, max, key: 'test' });
    assert.equal(blocked.limited, true);
    assert.ok(blocked.retryAfter > 0);
});

test('returns Retry-After in seconds', () => {
    checkRateLimit(req(), { windowMs: 10_000, max: 1, key: 'test' });
    const blocked = checkRateLimit(req(), { windowMs: 10_000, max: 1, key: 'test' });
    assert.equal(blocked.limited, true);
    assert.ok(blocked.retryAfter <= 10);
    assert.ok(blocked.retryAfter > 0);
});

test('different IPs have independent counters', () => {
    const limitedA = checkRateLimit(req({ ip: '1.1.1.1' }), { windowMs: 60_000, max: 1, key: 'test' });
    assert.equal(limitedA.limited, false);

    const blockedA = checkRateLimit(req({ ip: '1.1.1.1' }), { windowMs: 60_000, max: 1, key: 'test' });
    assert.equal(blockedA.limited, true);

    const limitedB = checkRateLimit(req({ ip: '2.2.2.2' }), { windowMs: 60_000, max: 1, key: 'test' });
    assert.equal(limitedB.limited, false);
});

test('different routes have independent counters', () => {
    checkRateLimit(req(), { windowMs: 60_000, max: 1, key: 'route-a' });
    const blockedA = checkRateLimit(req(), { windowMs: 60_000, max: 1, key: 'route-a' });
    assert.equal(blockedA.limited, true);

    const limitedB = checkRateLimit(req(), { windowMs: 60_000, max: 1, key: 'route-b' });
    assert.equal(limitedB.limited, false);
});

test('same IP different UIDs get separate counters', () => {
    const r1 = req({ ip: '10.0.0.1', auth: 'uid-one' });
    const r2 = req({ ip: '10.0.0.1', auth: 'uid-two' });

    checkRateLimit(r1, { windowMs: 60_000, max: 1, key: 'test' });
    const blockedR1 = checkRateLimit(r1, { windowMs: 60_000, max: 1, key: 'test' });
    assert.equal(blockedR1.limited, true);

    const limitedR2 = checkRateLimit(r2, { windowMs: 60_000, max: 1, key: 'test' });
    assert.equal(limitedR2.limited, false);
});

test('X-Forwarded-For is preferred over remoteAddress', () => {
    const r = req({ ip: '10.0.0.1', headers: { 'x-forwarded-for': '203.0.113.5' } });
    checkRateLimit(r, { windowMs: 60_000, max: 1, key: 'test' });

    const same = req({ ip: '10.0.0.2', headers: { 'x-forwarded-for': '203.0.113.5' } });
    const blocked = checkRateLimit(same, { windowMs: 60_000, max: 1, key: 'test' });
    assert.equal(blocked.limited, true);

    const different = req({ ip: '10.0.0.3', headers: { 'x-forwarded-for': '198.51.100.7' } });
    const allowed = checkRateLimit(different, { windowMs: 60_000, max: 1, key: 'test' });
    assert.equal(allowed.limited, false);
});

test('resetAll clears all counters', () => {
    checkRateLimit(req(), { windowMs: 60_000, max: 1, key: 'test' });
    assert.equal(checkRateLimit(req(), { windowMs: 60_000, max: 1, key: 'test' }).limited, true);
    resetAll();
    assert.equal(checkRateLimit(req(), { windowMs: 60_000, max: 1, key: 'test' }).limited, false);
});
