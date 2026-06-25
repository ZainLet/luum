import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const authStatusTrend = new Trend('auth_status_duration');
const syncUploadTrend = new Trend('sync_upload_duration');
const syncDownloadTrend = new Trend('sync_download_duration');
const classifyTrend = new Trend('classify_duration');

export const options = {
    stages: [
        { duration: '10s', target: 10 },
        { duration: '20s', target: 50 },
        { duration: '10s', target: 0 }
    ],
    thresholds: {
        errors: ['rate<0.01'],
        auth_status_duration: ['p(95)<800'],
        classify_duration: ['p(95)<2000'],
        http_req_duration: ['p(95)<3000']
    }
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || 'test-token';
const USER_ID = __ENV.USER_ID || 'load-test-user-001';

function randomPayload() {
    const timestamp = Date.now();
    return {
        schemaVersion: 1,
        account: { uid: USER_ID, email: 'loadtest@luum.app' },
        monitoringPreferences: {
            collectActivity: true,
            retentionDays: 30
        },
        activityLog: [],
        updatedAt: timestamp
    };
}

export default function () {
    const headers = {
        'Authorization': `Bearer ${AUTH_TOKEN}`,
        'Content-Type': 'application/json'
    };

    group('/api/auth/status', () => {
        const start = Date.now();
        const res = http.get(`${BASE_URL}/api/auth/status`, { headers });
        authStatusTrend.add(Date.now() - start);
        const ok = check(res, {
            'auth status retorna 200': (r) => r.status === 200,
            'auth status inclui plan': (r) => {
                try { return JSON.parse(r.body).plan !== undefined; }
                catch { return false; }
            }
        });
        errorRate.add(!ok);
    });

    sleep(1);

    group('/api/sync/:uid (POST)', () => {
        const start = Date.now();
        const res = http.post(`${BASE_URL}/api/sync/${USER_ID}`,
            JSON.stringify({ payload: randomPayload() }),
            { headers }
        );
        syncUploadTrend.add(Date.now() - start);
        const ok = check(res, {
            'sync upload retorna 200': (r) => r.status === 200,
            'sync upload retorna updatedAt': (r) => {
                try { return JSON.parse(r.body).updatedAt !== undefined; }
                catch { return false; }
            }
        });
        errorRate.add(!ok);
    });

    sleep(1);

    group('/api/sync/:uid (GET)', () => {
        const start = Date.now();
        const res = http.get(`${BASE_URL}/api/sync/${USER_ID}`, { headers });
        syncDownloadTrend.add(Date.now() - start);
        const ok = check(res, {
            'sync download retorna 200': (r) => r.status === 200,
            'sync download retorna payload': (r) => {
                try { return JSON.parse(r.body).payload !== undefined; }
                catch { return false; }
            }
        });
        errorRate.add(!ok);
    });

    sleep(1);

    group('/api/ai/classify', () => {
        const start = Date.now();
        const res = http.post(`${BASE_URL}/api/ai/classify`, JSON.stringify({
            action: 'classify',
            kind: 'application',
            label: 'Visual Studio Code',
            currentCategoryID: 'work',
            categories: [
                { id: 'work', title: 'Trabalho' },
                { id: 'entertainment', title: 'Entretenimento' }
            ]
        }), { headers });
        classifyTrend.add(Date.now() - start);
        const ok = check(res, {
            'classify retorna 200 ou 503': (r) => r.status === 200 || r.status === 503,
            'classify retorna categoryID ou erro': (r) => {
                try {
                    const b = JSON.parse(r.body);
                    return b.categoryID !== undefined || b.error !== undefined;
                } catch { return false; }
            }
        });
        errorRate.add(!ok);
    });

    sleep(1);
}
