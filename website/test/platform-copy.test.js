const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const websiteRoot = path.resolve(__dirname, '..');

test('sales page does not advertise unfinished desktop platforms as available', () => {
    const vendasHTML = fs.readFileSync(path.join(websiteRoot, 'vendas.html'), 'utf8');

    assert.doesNotMatch(vendasHTML, /disponível para macOS e Windows/i);
    assert.match(vendasHTML, /versão de teste atual é para macOS/i);
    assert.match(vendasHTML, /Windows está no roadmap/i);
    assert.match(vendasHTML, /Linux ainda está em estudo/i);
});
