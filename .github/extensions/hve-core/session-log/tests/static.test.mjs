// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const EXTENSION_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const HEADER = '// Copyright (c) 2026 Microsoft Corporation. All rights reserved.\n// SPDX-License-Identifier: MIT\n';

async function moduleFiles() {
    const entries = await fs.readdir(EXTENSION_DIR, { withFileTypes: true, recursive: true });
    return entries
        .filter((entry) => entry.isFile() && entry.name.endsWith('.mjs'))
        .map((entry) => path.join(entry.parentPath ?? entry.path, entry.name));
}

test('ships no package manifest', async () => {
    const entries = await fs.readdir(EXTENSION_DIR, { recursive: true });
    assert.equal(entries.some((name) => path.basename(String(name)) === 'package.json'), false);
});

test('every module carries the repository copyright header', async () => {
    for (const file of await moduleFiles()) {
        const text = await fs.readFile(file, 'utf8');
        assert.ok(text.startsWith(HEADER), path.relative(EXTENSION_DIR, file));
    }
});

test('imports only Node built-ins, the host SDK, and local modules', async () => {
    const importRe = /^\s*import\s+(?:[^'"]+\s+from\s+)?['"]([^'"]+)['"]/gm;
    for (const file of await moduleFiles()) {
        const text = await fs.readFile(file, 'utf8');
        for (const match of text.matchAll(importRe)) {
            const specifier = match[1];
            const allowed = specifier.startsWith('node:') || specifier.startsWith('./') || specifier.startsWith('../') || specifier === '@github/copilot-sdk/extension';
            assert.ok(allowed, `${path.relative(EXTENSION_DIR, file)} imports ${specifier}`);
        }
    }
});

test('contains no absolute user paths or stdout logging in runtime modules', async () => {
    for (const file of await moduleFiles()) {
        const relative = path.relative(EXTENSION_DIR, file);
        const text = await fs.readFile(file, 'utf8');
        assert.equal(/(?<![\w.-])\/Users\/|(?<![\w.-])\/home\/[a-z]|[A-Z]:\\\\Users\\\\/.test(text.replace(/C:\\\\Users\\\\dev|\/home\/user/g, '')), false, relative);
        if (!relative.startsWith('tests')) {
            assert.equal(/console\.(log|info|debug)\(/.test(text), false, relative);
            assert.equal(/process\.stdout/.test(text), false, relative);
        }
    }
});

test('the repository project entry only loads the packaged extension', async () => {
    const entry = path.join(EXTENSION_DIR, '..', '..', 'session-log', 'extension.mjs');
    const text = await fs.readFile(entry, 'utf8');
    assert.ok(text.startsWith(HEADER));
    const code = text.split('\n').filter((line) => line.trim() && !line.trim().startsWith('//'));
    assert.deepEqual(code, ["import '../hve-core/session-log/extension.mjs';"]);
    await fs.access(path.resolve(path.dirname(entry), '../hve-core/session-log/extension.mjs'));
});

test('the page shell has no inline scripts or styles', async () => {
    const html = await fs.readFile(path.join(EXTENSION_DIR, 'ui', 'index.html'), 'utf8');
    assert.equal(/<script(?![^>]*\bsrc=)[^>]*>/i.test(html), false);
    assert.equal(/<style\b/i.test(html), false);
    assert.equal(/\sstyle=/i.test(html), false);
    assert.equal(/\son[a-z]+=/i.test(html), false);
    assert.equal(/https?:\/\//i.test(html.replace('http://www.w3.org/2000/svg', '')), false);
});

test('the page shell defines every element ID and icon the UI uses', async () => {
    const html = await fs.readFile(path.join(EXTENSION_DIR, 'ui', 'index.html'), 'utf8');
    const app = await fs.readFile(path.join(EXTENSION_DIR, 'ui', 'app.mjs'), 'utf8');
    const render = await fs.readFile(path.join(EXTENSION_DIR, 'ui', 'render.mjs'), 'utf8');
    const ids = new Set([...html.matchAll(/\sid="([^"]+)"/g)].map((match) => match[1]));
    for (const [, id] of app.matchAll(/\$\('([^']+)'\)/g)) {
        assert.ok(ids.has(id), `missing element #${id}`);
    }
    const symbols = new Set([...html.matchAll(/<symbol id="([^"]+)"/g)].map((match) => match[1]));
    const used = [...html.matchAll(/href="#(i-[a-z-]+)"/g), ...`${app}\n${render}`.matchAll(/'(i-[a-z-]+)'/g)].map((match) => match[1]);
    for (const name of used) {
        assert.ok(symbols.has(name), `missing icon ${name}`);
    }
    const outline = html.slice(html.indexOf('id="panel-outline"'), html.indexOf('id="panel-details"'));
    assert.match(outline, /id="agentTree"[\s\S]*id="agentHeader"[\s\S]*id="interactionList"[\s\S]*class="tools-section"[\s\S]*id="toolSort"[\s\S]*id="toolIndex"/);
});
