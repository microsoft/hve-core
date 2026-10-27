// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const EXTENSION_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const HEADER = '// Copyright (c) 2026 Microsoft Corporation. All rights reserved.\n// SPDX-License-Identifier: MIT\n';

/** Reads a source file with LF line endings, as a Windows checkout may convert them to CRLF. */
async function readSource(file) {
    return (await fs.readFile(file, 'utf8')).replace(/\r\n/g, '\n');
}

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
        const text = await readSource(file);
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
    const text = await readSource(entry);
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
    assert.match(outline, /id="agentTree"[\s\S]*id="interactionList"/);
    assert.doesNotMatch(outline, /id="agentHeader"|id="toolIndex"/);
    const inspector = html.slice(html.indexOf('<aside id="inspector"'), html.indexOf('</aside>', html.indexOf('<aside id="inspector"')));
    assert.match(inspector, /id="inspectorHead"[\s\S]*id="agentHeader"[\s\S]*id="promptVersionList"[\s\S]*id="compactionList"[\s\S]*class="inspector-section tools-section"[\s\S]*id="toolSort"[\s\S]*id="toolIndex"/);
    assert.match(html, /id="sidebarToggle"[^>]*aria-controls="sidebar"/);
    assert.match(html, /id="inspectorToggle"[^>]*aria-controls="inspector"/);
});

test('the inspector switches between Activity and Context tab panels', async () => {
    const html = await fs.readFile(path.join(EXTENSION_DIR, 'ui', 'index.html'), 'utf8');
    const inspector = html.slice(html.indexOf('<aside id="inspector"'), html.indexOf('</aside>', html.indexOf('<aside id="inspector"')));
    assert.match(inspector, /id="inspectorHead"[\s\S]*role="tablist"[\s\S]*id="inspectorActivity"[\s\S]*id="inspectorContext"/);
    const tabs = [...inspector.matchAll(/<button id="(tab-[a-z]+)"[^>]*role="tab"[^>]*aria-selected="(true|false)"[^>]*aria-controls="([A-Za-z]+)"/g)].map((match) => match.slice(1));
    assert.deepEqual(tabs, [['tab-activity', 'true', 'inspectorActivity'], ['tab-context', 'false', 'inspectorContext']]);
    assert.match(inspector, /id="inspectorActivity"[^>]*role="tabpanel"[^>]*aria-labelledby="tab-activity"/);
    assert.match(inspector, /id="inspectorContext"[^>]*role="tabpanel"[^>]*aria-labelledby="tab-context"[^>]*hidden/);
    assert.match(inspector, />Tool calls <span id="toolHeadingCount"/);
    const context = inspector.slice(inspector.indexOf('id="inspectorContext"'));
    assert.match(context, /id="contextFilter"[\s\S]*id="contextStatus"[^>]*role="status"[\s\S]*id="contextSections"[\s\S]*id="contextDetail"[^>]*hidden/);
    const sidebarTabs = html.slice(html.indexOf('<aside id="sidebar"'), html.indexOf('</aside>'));
    assert.equal((sidebarTabs.match(/role="tab"/g) ?? []).length, 3);
});

test('every page module parses as an ES module', async () => {
    const dir = path.join(EXTENSION_DIR, 'ui');
    for (const name of (await fs.readdir(dir)).filter((file) => file.endsWith('.mjs'))) {
        assert.doesNotThrow(() => execFileSync(process.execPath, ['--check', path.join(dir, name)], { stdio: 'pipe' }), `${name} has a syntax error`);
    }
});

test('each side panel has a keyboard-focusable resize separator beside it', async () => {
    const html = await fs.readFile(path.join(EXTENSION_DIR, 'ui', 'index.html'), 'utf8');
    for (const [id, panel] of [['sidebarSplitter', 'sidebar'], ['inspectorSplitter', 'inspector']]) {
        const tag = new RegExp(`<div id="${id}"[^>]*>`).exec(html)?.[0] ?? '';
        assert.match(tag, /role="separator"/);
        assert.match(tag, /aria-orientation="vertical"/);
        assert.match(tag, new RegExp(`aria-controls="${panel}"`));
        assert.match(tag, /tabindex="0"/);
        assert.match(tag, /aria-label="Resize /);
    }
    assert.ok(html.indexOf('id="sidebarSplitter"') > html.indexOf('</aside>'), 'sidebar separator follows the sidebar');
    assert.ok(html.indexOf('id="inspectorSplitter"') < html.indexOf('<aside id="inspector"'), 'inspector separator precedes the inspector');
    assert.match(html, /id="instructionsSection"[^>]*hidden[\s\S]*id="agentInstructions"/);
});
