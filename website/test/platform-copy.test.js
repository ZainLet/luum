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

test('public pages do not sell unfinished advanced integrations as already available', () => {
    const pages = [
        fs.readFileSync(path.join(websiteRoot, 'index.html'), 'utf8'),
        fs.readFileSync(path.join(websiteRoot, 'vendas.html'), 'utf8'),
    ];

    for (const html of pages) {
        assert.doesNotMatch(html, /API & Webhooks/i);
        assert.doesNotMatch(html, /Integração com Zapier/i);
        assert.doesNotMatch(html, /Integrações com ClickUp/i);
    }

    assert.match(pages.join('\n'), /Conectores avançados em implantação/i);
});
