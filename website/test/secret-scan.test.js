const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.join(__dirname, '..', '..');
const ignoredDirectories = new Set([
    '.git',
    '.swiftpm',
    '.build',
    '.vercel',
    'dist',
    'node_modules'
]);

const ignoredFiles = new Set([
    'package-lock.json'
]);

const secretPatterns = [
    { name: 'Stripe secret key', pattern: /\b[rs]k_(?:live|test)_[A-Za-z0-9]{16,}\b/g },
    { name: 'Stripe webhook secret', pattern: /\bwhsec_[A-Za-z0-9]{16,}\b/g },
    { name: 'Gemini API key', pattern: /\bAQ\.[A-Za-z0-9_-]{20,}\b/g },
    { name: 'Resend API key', pattern: /\bre_[A-Za-z0-9_-]{20,}\b/g },
    { name: 'Firebase service account private key', pattern: new RegExp(`-----BEGIN ${'PRIVATE'} KEY-----`, 'g') }
];

function walk(directory, files = []) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
        if (ignoredDirectories.has(entry.name)) continue;

        const fullPath = path.join(directory, entry.name);
        if (entry.isDirectory()) {
            walk(fullPath, files);
        } else if (!ignoredFiles.has(entry.name)) {
            files.push(fullPath);
        }
    }
    return files;
}

function isTextFile(filePath) {
    const buffer = fs.readFileSync(filePath);
    if (buffer.includes(0)) return false;
    return buffer.length < 1_000_000;
}

function isAllowedFixture(match) {
    const lowered = match.toLowerCase();
    return lowered.includes('should_not_leak') ||
        lowered.includes('test') ||
        lowered.includes('fake') ||
        lowered.includes('example');
}

test('repository does not contain committed private integration secrets', () => {
    const findings = [];

    for (const filePath of walk(repoRoot)) {
        if (!isTextFile(filePath)) continue;

        const relativePath = path.relative(repoRoot, filePath);
        const contents = fs.readFileSync(filePath, 'utf8');

        for (const { name, pattern } of secretPatterns) {
            pattern.lastIndex = 0;
            for (const match of contents.matchAll(pattern)) {
                if (isAllowedFixture(match[0])) continue;
                findings.push(`${name} in ${relativePath}`);
            }
        }
    }

    assert.deepEqual(findings, []);
});
