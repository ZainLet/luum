const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const packageJSON = JSON.parse(
    fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8')
);

test('website API runtime stays compatible with firebase-admin 14', () => {
    assert.match(packageJSON.dependencies['firebase-admin'], /\^14\./);
    assert.match(packageJSON.engines.node, />=22/);
});
